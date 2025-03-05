local M = {}

M.servers = {}

function M.setup(config)
    M.servers = {}

    for order, server in pairs(config.servers or {}) do
        table.insert(M.servers, {
            name = server.name,
            host = server.host,
            user = server.user,
            password = server.password,
            root = server.root
        })
    end
end

local function select_server(callback)
    if #M.servers == 0 then
        notify("⚠️ No FTP servers configured!", vim.log.levels.WARN)
        return
    end

    local choices = {}

    for i, server in ipairs(M.servers) do
        choices[i] = server.name
    end

    vim.ui.select(choices, { prompt = "Select FTP Server:" }, function(choice)
        if choice then
            for _, server in ipairs(M.servers) do
                if server.name == choice then
                    callback(server)
                    break
                end
            end
        end
    end)
end

local function get_relative_path(filepath)
    local cwd = vim.fn.getcwd()
    local rel_path = filepath:gsub("^" .. vim.pesc(cwd), "")
    return rel_path:gsub("^/*", "")
end

local function notify(msg, type)
    vim.notify(msg, type or vim.log.levels.INFO)
end

local function clean_data(data)
    local result = {}
    for _, line in ipairs(data) do
        local cleaned = line:gsub("\r", "")
        if cleaned ~= "" then
            table.insert(result, cleaned)
        end
    end
    return table.concat(result, "\n")
end

local function get_filename(filepath)
    return vim.fn.fnamemodify(filepath, ":t")
end

local function confirm_action(action, server, remote_path, filepath)
    local filename = get_filename(filepath)
    local prompt = string.format("Are you sure you want to %s '%s' to/from '%s'? (y/n)", action, filename, server.name)
    vim.ui.input({ prompt = prompt }, function(input)
        if input and input:lower() == "y" then
            if action == "upload" then
                M.upload_file(server, remote_path, filepath)
            elseif action == "download" then
                M.download_file(server, remote_path, filepath)
            end
        else
            notify("❌ Operation cancelled.", vim.log.levels.WARN)
        end
    end)
end

function M.upload_file(server, remote_path, filepath)
    local cmd = string.format(
        "curl -T '%s' ftp://%s%s --user %s:%s --silent --show-error --write-out '%%{stderr}'",
        filepath, server.host, remote_path, server.user, server.password
    )
    
    local stderr_output = {}

    vim.fn.jobstart(cmd, {
        on_stdout = function(_, data)
            if data and #data > 0 then
                -- notify(table.concat(data, '\n'))
            end
        end,
        on_stderr = function(_, data)
            if data and #data > 0 then
                table.insert(stderr_output, table.concat(data, '\n'))
            end
        end,
        on_exit = function(_, code)
            if code == 0 then
                notify("Uploaded " .. get_filename(remote_path), vim.log.levels.INFO)
            else
                notify("Upload failed!\n" .. table.concat(stderr_output, '\n'), vim.log.levels.ERROR)
            end
        end
    })
end

function M.download_file(server, remote_path, filepath)
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
                notify("Downloaded " .. get_filename(remote_path), vim.log.levels.INFO)
            else
                notify("Download failed!\n" .. table.concat(stderr_output, '\n'), vim.log.levels.ERROR)
            end
        end
    })
end

function M.upload()
    local filepath = vim.fn.expand('%:p')
    local rel_path = get_relative_path(filepath)
    
    select_server(function(server)
        local remote_path = server.root .. rel_path
        confirm_action("upload", server, remote_path, filepath)
    end)
end

function M.download()
    local filepath = vim.fn.expand('%:p')
    local rel_path = get_relative_path(filepath)
    
    select_server(function(server)
        local remote_path = server.root .. rel_path
        confirm_action("download", server, remote_path, filepath)
    end)
end

return M
