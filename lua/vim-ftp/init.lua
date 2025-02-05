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

function M.upload()
    local filepath = vim.fn.expand('%:p')
    local rel_path = get_relative_path(filepath)
    
    select_server(function(server)
        local remote_path = server.root .. rel_path
        local cmd = string.format(
            "curl -T '%s' ftp://%s%s --user %s:%s",
            filepath, server.host, remote_path, server.user, server.password
        )
        vim.fn.system(cmd)
        print("Uploaded to " .. remote_path)
    end)
end

function M.download()
    local filepath = vim.fn.expand('%:p')
    local rel_path = get_relative_path(filepath)
    
    select_server(function(server)
        local remote_path = server.root .. rel_path
        local cmd = string.format(
            "curl -o '%s' ftp://%s%s --user %s:%s",
            filepath, server.host, remote_path, server.user, server.password
        )
        vim.fn.system(cmd)
        print("Downloaded from " .. remote_path)
    end)
end

return M
