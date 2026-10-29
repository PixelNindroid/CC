local informativeRegistry = peripheral.find('informative_registry')
local recipeRegistry = peripheral.find('recipe_registry')
local crafter = peripheral.find('turtle')
local crafterContainerID = peripheral.getName(crafter)

local peripherals = n.mapPeripherals()

if not peripherals.wirelessModems then
    printError('Wireless modem not found')
    return
end
rednet.open(peripherals.wirelessModems[1])

write('Hosting..')
rednet.host('SFR_SERVER', 'sfr_server')
n.printRight('Done', colors.green)

local function getStock()
    for _, containerID in pairs(peripherals.containers) do
        peripheral.wrap(containerID).items()
    end
end