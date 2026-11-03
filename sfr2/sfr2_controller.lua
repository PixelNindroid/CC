local grab = require('libs.grab')
local n = require('libs.ninlib')
local r = require('libs.redlib')
local registry = require('libs.registry')
local pretty = require('cc.pretty')

local peripherals = n.mapPeripherals()

local crafter = peripheral.find('turtle')
local crafterContainerID = peripheral.getName(crafter)

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

local function getContainerItemList(container)
    if container.list then
        return container.list()
    elseif container.items then
        return container.items()
    else
        printError('Container ' .. containerID .. ' does not have a list or items method')
        return {}
    end
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
        for _, v in pairs(getContainerItemList(container)) do
            addToItemMap(map, v.name, v.count, containerID)
            totalTotalCount = totalTotalCount + v.count
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

    for slot, item in pairs(getContainerItemList(peripheral.wrap(containerID))) do
        if item.name == itemID then table.insert(slots, slot) end
    end

    return slots
end
local function moveItemFromToSlot(itemID, from, to, toSlot, limit) --to must be slotted
    local toMove = limit or registry.itemDetails[itemID].maxCount
    local fromContainer = peripheral.wrap(from)

    if fromContainer.items then --unslotted, use tempStorage
        local moved = fromContainer.pushItems(tempStorageID, itemID, toMove)
        return moveItemFromToSlot(itemID, tempStorageID, to, toSlot, moved)
    end

    if fromContainer.list then --slotted
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
end
    

local function moveItemTo(itemID, to, toSlot, limit)
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
