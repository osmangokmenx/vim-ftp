local M = {}

M.servers = {}

function M.setup(config)
    M.servers = config.servers or {}
end

local function select_server(callback)
    local choices = {}
    for name, _ in pairs(M.servers) do
        table.insert(choices, name)
    end
    
    vim.ui.select(choices, { prompt = "Select FTP Server:" }, function(choice)
        if choice then
            callback(M.servers[choice])
        end
    end)
end

local function get_relative_path(filepath)
    local cwd = vim.fn.getcwd()
    return filepath:gsub(cwd, "")
end

local function notify(msg, type)
    vim.notify(msg, type or vim.log.levels.INFO)
end

local function clean_data(data)
    local result = {}
    for _, line in ipairs(data) do
        local cleaned = line:gsub("\r", "") -- ^M karakterlerini temizle
        if cleaned ~= "" then
            table.insert(result, cleaned)
        end
    end
    return table.concat(result, "\n")
end

function M.upload()
    local filepath = vim.fn.expand('%:p')
    local rel_path = get_relative_path(filepath)
    
    select_server(function(server)
        local remote_path = server.root .. rel_path
        local cmd = string.format(
            "curl -T '%s' ftp://%s%s --user %s:%s --silent --show-error --write-out '%%{stderr}'",
            filepath, server.host, remote_path, server.user, server.password
        )
        
        local stderr_output = {}

        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if data and #data > 0 then
                    notify(table.concat(data, '\n'))
                end
            end,
            on_stderr = function(_, data)
                if data and #data > 0 then
                    table.insert(stderr_output, table.concat(data, '\n'))
                end
            end,
            on_exit = function(_, code)
                if code == 0 then
                    notify("✅ Uploaded to " .. remote_path, vim.log.levels.INFO)
                else
                    notify("❌ Upload failed!\n" .. table.concat(stderr_output, '\n'), vim.log.levels.ERROR)
                end
            end
        })
    end)
end

function M.download()
    local filepath = vim.fn.expand('%:p')
    local rel_path = get_relative_path(filepath)
    
    select_server(function(server)
        local remote_path = server.root .. rel_path
        local cmd = string.format(
            "curl -o '%s' ftp://%s%s --user %s:%s --silent --show-error --write-out '%%{stderr}'",
            filepath, server.host, remote_path, server.user, server.password
        )

        local stderr_output = {}

        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if data and #data > 0 then
                    notify(table.concat(data, '\n'))
                end
            end,
            on_stderr = function(_, data)
                if data and #data > 0 then
                    table.insert(stderr_output, table.concat(data, '\n'))
                end
            end,
            on_exit = function(_, code)
                if code == 0 then
                    notify("✅ Downloaded from " .. remote_path, vim.log.levels.INFO)
                else
                    notify("❌ Download failed!\n" .. table.concat(stderr_output, '\n'), vim.log.levels.ERROR)
                end
            end
        })
    end)
end

return M
