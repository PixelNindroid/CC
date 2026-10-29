local n = require('libs.ninlib')
local r = require('libs.redlib')
local grab = require('libs.grab')
local registry = require('libs.registry')
local pretty = require('cc.pretty')

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




--MAP



--{itemID = {'containerCount' = {containerID = count}, 'totalCount' = totalCount}
local function addToItemMap(map, itemID, count, containerID)
    if not map[itemID] then
        map[itemID] = {containerCount = {}, totalCount = 0}
    end
    if not map[itemID].containerCount[containerID] then
        map[itemID].containerCount[containerID] = 0
    end
    map[itemID].containerCount[containerID] = map[itemID].containerCount[containerID] + count
    map[itemID].totalCount = map[itemID].totalCount + count

    return map
end
local function getItemMap() 
    write('Mapping items..')
    local map = {}
    local totalTotalCount = 0

    for _, containerID in pairs(peripherals.containers) do
        local container = peripheral.wrap(containerID)
        if container.list then
            for _, v in pairs(container.list()) do
                addToItemMap(map, v.name, v.count, containerID)
                totalTotalCount = totalTotalCount + v.count
            end
        elseif container.items then
            for _, v in pairs(container.items()) do
                addToItemMap(map, v.name, v.count, containerID)
                totalTotalCount = totalTotalCount + v.count
            end
        end
    end

    printSucces(n.getTableLength(map), nil, totalTotalCount)
    return map
end

local function listen(id, msg, ptc)
    r.listen(id, msg, ptc, {}, {})
end

while true do
    local eventData = {os.pullEvent()}
    local event = eventData[1]

    redstone.setOutput('left', true)

    if event == 'rednet_message' then
        local id, msg, ptc = table.unpack(eventData, 2)
        listen(id, msg, ptc)
    end

    redstone.setOutput('left', false)
end
