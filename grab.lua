local pretty = require('cc.pretty')

local DEPENDENCIES = {
    sfr_server = {'sfrlib', 'ninlib', 'redlib'},
    sfr_client = {'sfrlib', 'ninlib', 'redlib', 'makeup'},
    sfr_crafter = {'redlib'}
}
local CATEGORIES = {
    ['sfr_server.lua'] = 'sfr',
    ['sfr_client.lua'] = 'sfr',
    ['sfr_crafter.lua'] = 'sfr',
    ['sfrlib.lua'] = 'sfr'
}
local GIT_REPO_URL = 'https://raw.githubusercontent.com/PixelNindroid/CC/main/'
local grab = {}


function grab.put(path, text)
    local f = fs.open(path, 'w')
    if not f then
        printError("Failed to open file for writing: " .. path)
    end
    f.write(text)
    f.close()
end
function grab.serialize(path, data)
    grab.put(path, textutils.serialize(data))
end
function grab.serializeJSON(path, data)
    grab.put(path, textutils.serializeJSON(data))
end

function grab.pull(path)
    local f = fs.open(path, 'r')
    if not f then
        printError("Failed to open file for reading: " .. path)
        return nil
    end
    local text = f.readAll()
    f.close()
    
    return text
end
function grab.unserialize(path)
    local text = grab.pull(path)
    return text and textutils.unserialize(text) or nil
end
function grab.unserializeJSON(path)
    local text = grab.pull(path)
    return text and textutils.unserializeJSON(text) or nil
end

local function getGitRepo(fileName)
    local category = CATEGORIES[fileName]
    local subfolder = category and (category .. '/') or ''
    local url = string.format('%s%s%s', GIT_REPO_URL, subfolder, fileName)

    local request
    repeat
        request = http.get(url, {["Cache-Control"] = "no-cache", ["Pragma"] = "no-cache"})

        if not request then
            print('HTTP request for '..fileName..' failed!')
            sleep(1)
        end
    until request

    local fileContents = request.readAll()
    request.close()

    return fileContents
end

local function grabLib(name)
    local fileName = name..'.lua'
    write('  Grabbing '..name..'..')
    grab.put('/libs/'..fileName, getGitRepo(fileName))
    print('  Done.')

end
local function refreshGit()
    write('Checking API for latest push... ')
    local url = "https://api.github.com/repos/PixelNindroid/CC/commits/main"
    local response = http.get(url, {["User-Agent"] = "ComputerCraft"})
    
    if response then
        local data = textutils.unserializeJSON(response.readAll())
        response.close()
        
        if data and data.sha then
            -- The Magic: Overwrite the URL to use the exact commit hash instead of 'main'
            GIT_REPO_URL = 'https://raw.githubusercontent.com/PixelNindroid/CC/' .. data.sha .. '/'
            print(string.sub(data.sha, 1, 7))
            return
        end
    end
    print('Failed. Falling back to cached main.')
end
function grab.grabAll(main)
    refreshGit()

    local mainFileName = main..'.lua'
    grabLib('grab')
    print('\nGrabbing '..main..'..')

    grab.put(mainFileName, getGitRepo(mainFileName))
    print('Done.')

    for _, lib in pairs(DEPENDENCIES[main]) do
        grabLib(lib)
    end
    print('\nLibs Updated Succesfully\n')
end

local function installer()
    print('Choose the main program:')
    local main = read()

    os.setComputerLabel(main)

    os.reboot()
end

settings.load()
if not settings.get('grab.grab_scripts_on_startup') then
    settings.define('grab.grab_scripts_on_startup', {default = true})
    settings.save()
end

if not fs.exists('startup.lua') then 
    installer()
end

return grab