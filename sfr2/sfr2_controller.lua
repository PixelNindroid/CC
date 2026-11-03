local grab = require('libs.grab')
local n = require('libs.ninlib')
local r = require('libs.redlib')
local registry = require('libs.registry')
local pretty = require('cc.pretty')

local peripherals = n.mapPeripherals()

local crafter = peripheral.find('turtle')
local crafterContainerID = peripheral.getName(crafter)

local mainStorageContainerType = 'neepmeat:flex_silo'

local tempStorage = peripheral.find('minecraft:trapped_chest')
local tempStorageID = peripheral.getName(tempStorage)


if not peripherals.wirelessModems then
    printError('Wireless modem not found')
    return
end
rednet.open(peripherals.wirelessModems[1])

write('Hosting..')
rednet.host('SFR2_CONTROLLER', 'controller')
n.printRight('Done', colors.green)


--MAP

local function getContainerItemData(container)
    if container.list then
        return container.list()
    elseif container.items then
        return container.items()
    else
        printError('Container ' .. containerID .. ' does not have a list or items method')
        return {}
    end
end
local function getContainerItemCounts(container)
    local counts = {}
    for _, item in pairs(getContainerItemData(container)) do
        counts[item.name] = (counts[item.name] or 0) + item.count
    end
    return counts
end

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
        for _, item in pairs(getContainerItemData(container)) do
            addToItemMap(map, item.name, item.count, containerID)
            totalTotalCount = totalTotalCount + item.count
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

    for slot, item in pairs(getContainerItemData(peripheral.wrap(containerID))) do
        if item.name == itemID then table.insert(slots, slot) end
    end

    return slots
end
local function moveItemsFromSlotsTo(slots, from, to, limit, toSlot)
    local fromContainer = peripheral.wrap(from)
    local toMove = limit or 10000

    for i = #slots, 1, -1 do
        local fromSlot = slots[i]
        local moved = fromContainer.pushItems(to, fromSlot, toMove, toSlot)

        if moved > 0 then
            print(('Moved %d items from %s to %s'):format(moved, from, to))
        else
            printError(('Failed to move slot %s from %s to %s'):format(fromSlot, from, to))
        end

        toMove = toMove - moved
        if toMove <= 0 then break end
    end
end
local function moveItemsFromTo(itemID, from, to, limit)
    local fromContainer = peripheral.wrap(from)
    if fromContainer.items then 
        fromContainer.pushItem(to, itemID, limit)
    elseif fromContainer.list then
        local slots = getSlots(itemID, from)
        moveItemsFromSlotsTo(slots, from, to, limit)
    end
end
local function moveItemFromToSlot(itemID, from, to, toSlot, limit) --to must be slotted
    if not itemMap[itemID] then
        printError('Item not found in any container: ' .. itemID)
        return
    end
    local toMove = limit or registry.itemDetails[itemID].maxCount
    local fromContainer = peripheral.wrap(from)

    if fromContainer.items then --unslotted, use tempStorage
        local moved = fromContainer.pushItem(tempStorageID, itemID, toMove)
        return moveItemFromToSlot(itemID, tempStorageID, to, toSlot, moved)
    end

    if fromContainer.list then --slotted
        local slots = getSlots(itemID, from)
        moveItemsFromSlotsTo(slots, from, to, toMove, toSlot)
    end
end  
local function moveItemTo(itemID, to, toSlot, limit)
    if not itemMap[itemID] then
        printError('Item not found in any container: ' .. itemID)
        return
    end
    local toMove = limit or registry.itemDetails[itemID].maxCount

    print(itemID)
    for from in pairs(itemMap[itemID].containerCount) do
        if from ~= to then
            local moved = moveItemFromToSlot(itemID, from, to, toSlot, toMove)
            if moved and (moved > 0) then
                toMove = toMove - moved
                if toMove <= 0 then break end
            end
        end
    end
end

local function getSortLoc(itemID)
    local containerID = peripheral.getName(peripheral.find(mainStorageContainerType))
    
    return containerID
end
local function sort(containerID)
    local container = peripheral.wrap(containerID)
    if not container then
        printError('Container not found: ' .. containerID)
        return
    end

    for itemID in pairs(getContainerItemCounts(container)) do
        moveItemsFromTo(itemID, containerID, getSortLoc(itemID))
    end
    
end

remap()
sort(crafterContainerID)
sort(tempStorageID)
remap()

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
