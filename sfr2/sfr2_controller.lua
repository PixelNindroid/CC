local informativeRegistry = peripheral.find('informative_registry')
local recipeRegistry = peripheral.find('recipe_registry')
local crafter = peripheral.find('turtle')
local crafterContainerID = peripheral.getName(crafter)

local storageContainers = {peripheral.wrap('neepmeat:flex_silo_0')}

if not Peripherals.wirelessModems then
    printError('Wireless modem not found')
    return
end
rednet.open(Peripherals.wirelessModems[1])

write('Hosting..')
rednet.host('SFR_SERVER', 'sfr_server')
n.printRight('Done', colors.green)

local function getStock()
    
end