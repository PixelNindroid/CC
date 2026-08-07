local r = require('libs.redlib')

peripheral.find("modem", rednet.open)
--rednet.host('SFR_CRAFTER', 'sfr_crafter')

print('Hosting..')
rednet.host('SFR_CRAFTER', 'sfr_crafter')
print('Done!')


local function craft()
    local craftSucces = turtle.craft()

    if craftSucces then
        print('Craft!')
    else
        printError('Couldn\'t craft :(')
    end
    
    return craftSucces
end

while true do
    local id, msg = rednet.receive('ACTION')
    r.listen(id, msg, 'ACTION', {
        craft = craft
    })
end