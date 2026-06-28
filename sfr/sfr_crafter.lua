local r = require('libs.redlib')

peripheral.find("modem", rednet.open)
--rednet.host('SFR_CRAFTER', 'sfr_crafter')

print('Hosting..')
rednet.host('SFR_CRAFTER', 'sfr_crafter')
print('Done!')
 

local function craft()
    turtle.craft()
    print('Craft!')
end
print('jee')

while true do
    local id, msg = rednet.receive('ACTION')
    r.listen(id, msg, 'ACTION', {
        craft = craft
    })
end