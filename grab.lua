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
local GIT_REPO_URL = 'https://raw.githubusercontent.com/PixelNindroid/CC/refs/heads/main/'
local VERSION_FILE_NAME = 'version.txt'
local VERSION_FILE_PATH = '/version.txt'
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

local function trim(str)
    return (string.gsub(str or '', '^%s*(.-)%s*$', '%1'))
end

local function getGitRepo(fileName)
    local link = string.format('%s%s/%s?t=%s', GIT_REPO_URL, CATEGORIES[fileName] or '', fileName, os.epoch("utc"))
    local request

    while not request do
        request = http.get(link)

        if not request then
            print('HTTP request for '..fileName..' failed!')
            sleep(1)
        end
    end

    local fileContents = request.readAll()
    request.close()

    return fileContents
end

local function getRemoteVersion()
    local versionText = getGitRepo(VERSION_FILE_NAME)
    return trim(versionText)
end

local function shouldUpdateFiles(remoteVersion)
    if not fs.exists(VERSION_FILE_PATH) then
        return true
    end

    local localVersion = grab.pull(VERSION_FILE_PATH)
    return trim(localVersion) ~= remoteVersion
end

local function grabLib(name, updateNeeded)
    local fileName = name..'.lua'
    local destinationPath = '/libs/'..fileName

    if not updateNeeded and fs.exists(destinationPath) then
        return
    end

    write('  Grabbing '..name..'..')
    grab.put(destinationPath, getGitRepo(fileName))
    print('  Done.')
end

function grab.grabAll(main)
    local mainFileName = main..'.lua'
    local remoteVersion = getRemoteVersion()
    local updateNeeded = shouldUpdateFiles(remoteVersion)

    if updateNeeded then
        grab.put(VERSION_FILE_PATH, remoteVersion)
    else
        print('Repo version unchanged ('..remoteVersion..'); using existing files.\n')
    end

    grabLib('grab', updateNeeded)
    print('\nGrabbing '..main..'..')

    if updateNeeded or not fs.exists(mainFileName) then
        grab.put(mainFileName, getGitRepo(mainFileName))
        print('Done.')
    else
        print('Up to date.')
    end

    for _, lib in pairs(DEPENDENCIES[main]) do
        grabLib(lib, updateNeeded)
    end
    print('\nLibs Updated Succesfully\n')
end


if not fs.exists('startup.lua') then 
	grabLib('grab')

    print('Choose the main program:')
    local main = read()

    grab.put('/startup.lua', 
        ([[
local grab = require('libs.grab')
local main = '%s'

term.clear()
grab.grabAll(main)

print('Running ' .. main .. '..\n')
shell.run(main)

        ]]):format(main)
    )

    os.setComputerLabel(main)

    os.reboot()
end

return grab