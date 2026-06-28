local pretty = require('cc.pretty')

local DEPENDENCIES = {
    sfr_server = {'sfrlib', 'ninlib', 'redlib'},
    sfr_client = {'sfrlib', 'ninlib', 'redlib', 'makeup'},
    sfr_crafter = {'redlib'}
}
local CATEGORIES = {
    grab = '4iVMG0am',
	sfrlib = 'SZ8WbcZ1',
    ninlib = 'xG3Juhci',
    redlib = 'ZTCVsg2p',
    makeup = 'BYuuS1M5'
}
local GIT_REPO_URL = 'https://raw.githubusercontent.com/PixelNindroid/CC/refs/heads/main/'
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
    local link = GIT_REPO_URL .. fileName
    local request

    while not request do
        request = http.get(link)
        pretty.pretty_print(request)
        read()

        if not request then
            print('HTTP request for '..fileName..' failed!')
            sleep(1)
        end
    end

    local fileContents = request.readAll()
    request.close()

    return fileContents
end

local function grabLib(name)
    local fileName = name..'.lua'
    write(' Grabbing '..name..'..')
    grab.put('/libs/'..fileName, getGitRepo(fileName))
    print(' Done.')

end
function grab.grabAll(main)
    grabLib('grab')
    print('\nGrabbing dependencies for '..main..'..')

    for _, lib in pairs(DEPENDENCIES[main]) do
        grabLib(lib)
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