local n = require('libs.ninlib')
local r = require('libs.redlib')
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
rednet.host('SFR2_CONTROLLER', 'controller')
n.printRight('Done', colors.green)


--MAP

local itemMap --{itemID = {'containerCount' = {containerID = count}, 'totalCount' = totalCount}
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

    n.printSucces(totalTotalCount)
    return map
end
local function remap()
    itemMap = getItemMap()
    return itemMap
end

local function getSlots(itemID, containerID)
    local slots = {}

    for slot, item in pairs(peripheral.wrap(containerID).list()) do
        if item.name == itemID then table.insert(slots, slot) end
    end

    return slots
end
local function moveItem(from, to, toSlot, limit)
    local toMove = limit or registry.itemDetails[itemID].maxCount
    local fromContainer = peripheral.wrap(from)
    local slots = getSlots(itemID, from)

    for i = #slots, 1, -1 do
        local fromSlot = slots[i]
        local moved = fromContainer.pushItems(to, fromSlot, limit, toSlot)

        if moved > 0 then
            print(('Moved %d items from %s to %s'):format(moved, from, to))
        else
            printError(('Failed to move slot %s from %s to %s'):format(fromSlot, from, to))
        end

        toMove = toMove - moved
        if toMove <= 0 then break end
    end
end

local function moveItemTo(itemID, to, toSlot, limit)
    local toMove = limit or registry.itemDetails[itemID].maxCount

    print(itemID)
    for from in pairs(itemMap[itemID].containerCount) do
        if from ~= to then
            local moved = moveItem(from, to, toSlot, toMove)

            toMove = toMove - moved
            if toMove <= 0 then break end
        end
    end
end

remap()
pretty.pretty_print(itemMap)
read()
local function listen(id, msg, ptc)
    r.listen(id, msg, ptc, {

        remap = remap,
        moveItemToCrafter = function (itemID, toSlot, limit)
            moveItemTo(itemID, crafterContainerID, toSlot, limit)
            
        end

    }, {
        registry = registry,
    })
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
