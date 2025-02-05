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

function M.upload()
    local filepath = vim.fn.expand('%:p')
    local rel_path = get_relative_path(filepath)
    
    select_server(function(server)
        local remote_path = server.root .. rel_path
        local cmd = string.format(
            "curl -T '%s' ftp://%s%s --user %s:%s --progress-bar",
            filepath, server.host, remote_path, server.user, server.password
        )
        
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if data then
                    notify(table.concat(data, '\n'))
                end
            end,
            on_stderr = function(_, data)
                if data then
                    notify("Error: " .. table.concat(data, '\n'), vim.log.levels.ERROR)
                end
            end,
            on_exit = function(_, code)
                if code == 0 then
                    notify("Uploaded to " .. remote_path, vim.log.levels.INFO)
                else
                    notify("Upload failed!", vim.log.levels.ERROR)
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
            "curl -o '%s' ftp://%s%s --user %s:%s --progress-bar",
            filepath, server.host, remote_path, server.user, server.password
        )
        
        vim.fn.jobstart(cmd, {
            on_stdout = function(_, data)
                if data then
                    notify(table.concat(data, '\n'))
                end
            end,
            on_stderr = function(_, data)
                if data then
                    notify("Error: " .. table.concat(data, '\n'), vim.log.levels.ERROR)
                end
            end,
            on_exit = function(_, code)
                if code == 0 then
                    notify("Downloaded from " .. remote_path, vim.log.levels.INFO)
                else
                    notify("Download failed!", vim.log.levels.ERROR)
                end
            end
        })
    end)
end

return M
