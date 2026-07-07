local sfr = require('libs.sfrlib')
local n = require('libs.ninlib')
local r = require('libs.redlib')
local grab = require('libs.grab')
local pretty = require('cc.pretty')
C = sfr.C

local TICK_DELAY = 1
local ACTIVE_STATE_DURATION = 0.5
local lastMovementTime = 0
local activeState = false

local Peripherals = n.mapPeripherals()
local speaker = peripheral.find('speaker')
local crafter = peripheral.find('turtle') --TODO
local crafterContainerID = peripheral.getName(crafter)
local informativeRegistry = peripheral.find('informative_registry')
local recipeRegistry = peripheral.find('recipe_registry')

if not Peripherals.wirelessModems then
    printError('Wireless modem not found')
    return
end
rednet.open(Peripherals.wirelessModems[1])

write('Hosting..')
rednet.host('SFR_SERVER', 'sfr_server')
n.printRight('Done', colors.green)

local crafterID = r.getHostID('SFR_CRAFTER')

for type in pairs(C) do -- load containers
    C[type] = grab.unserialize(sfr.path[type]) or {}
end
local SavedRecipes = grab.unserialize('data/saved_recipes.dat') or {}
local SavedTagInputs = grab.unserialize('data/saved_tag_inputs.dat') or {}

local function save(path, data)
    grab.serialize(path, data)
    n.write('Saved ', colors.green)
    n.print(path, colors.lightGray)
end
local function saveC(type)
    save(sfr.path[type], C[type])
end
local function saveAllC()
    for type in pairs(C) do
        saveC(type)
    end
end


--SORT

local function moveItemsFromSlots(from, to, slots, limit, toSlot)
    if not slots then 
        printError('Needs slot.')
        return 0
    end
    local fromContainer = peripheral.wrap(from)
    local totalMoved = 0

    if type(slots) == 'number' then slots = {slots} end
    limit = limit or 10000

    for i = #slots, 1, -1 do
        local slot = slots[i]
        local moved = fromContainer.pushItems(to, slot, limit, toSlot)

        if moved > 0 then
            speaker.playNote('iron_xylophone', 3, 8)
            lastMovementTime = os.epoch('utc')
            activeState = true
            print(('Moved %d items from %s to %s'):format(moved, from, to))
        else
            speaker.playNote('xylophone', 1, 8)
            printError(('Failed to move slot %s from %s to %s'):format(slot, from, to))
        end

        totalMoved = totalMoved + moved
        limit = limit - moved
        if limit <= 0 then break end
    end

    return totalMoved
end
local function hasEmptySlots(id)
    local container = peripheral.wrap(id)
    return container.size() > #container.list()
end
local function canPush(itemID, to)
    if hasEmptySlots(to) then return true end

    for _, item in pairs(peripheral.wrap(to).list()) do
        if item.name == itemID and item.count < ItemDetails[itemID].maxCount then
            return true
        end
    end
    return false
end
local pullFromBulk
local function moveItemsFromContainers(froms, to, itemID, limit, toSlot)
    if not canPush(itemID, to) then return 0 end

    local totalMoved = 0
    if type(froms) == 'string' then froms = {froms} end
    limit = limit or 10000

    for i = #froms, 1, -1 do
        local from = froms[i]
        local moved = sfr.getContainerType(from) == 'BulkInterface' and pullFromBulk(to, from, itemID, limit - 64) or moveItemsFromSlots(from, to, sfr.getSlots(itemID, from), limit, toSlot)

        print(itemID, from, limit, toSlot)
        totalMoved = totalMoved + moved
        limit = limit - moved
        if limit <= 0 then break end
    end

    return totalMoved
end
local function moveItemsFromAnywhere(to, itemID, limit, toSlot)
    local totalMoved = 0
    limit = limit or 10000

    while true do
        local from = sfr.getItemLoc(itemID)
        if not from then break end

        local moved = moveItemsFromContainers(from, to, itemID, limit, toSlot)

        totalMoved = totalMoved + moved
        limit = limit - moved
        if limit <= 0 then break end
    end

    return totalMoved
end

local function findStorage(itemID)
    local tagLoc = sfr.getTagLoc(itemID)
    if tagLoc then return tagLoc end

    local itemLoc = sfr.getItemLoc(itemID)
    if itemLoc then return itemLoc end
end

local function pushToBulk(from, bulkInterfaceID, slot, count)
    local bulks = C.BulkInterface[bulkInterfaceID].bulks

    for _, bulk in pairs(bulks) do
        count = count - moveItemsFromSlots(from, bulk, slot, count)
        if count <= 0 then return end
    end
end
local function isContainerEmpty(id)
    return next(peripheral.wrap(id).list()) == nil
end
pullFromBulk = function(to, bulkInterfaceID, itemID, count)
    local bulks = C.BulkInterface[bulkInterfaceID].bulks

    for i = #bulks, 1, -1 do
        local bulk = bulks[i]

        if not isContainerEmpty(bulk) then
            count = count - moveItemsFromContainers(bulk, to, itemID, count)
            if count <= 0 then return end
        end
    end
end

local function sortSlot(containerID, slot, item)
    item = item or peripheral.wrap(containerID).list()[slot]

    --to bulk
    local bulkInterfaceID = sfr.getItemLoc(item.name, 'BulkInterface')
    if bulkInterfaceID then
        pushToBulk(containerID, bulkInterfaceID, slot, item.count) 
    end

    --to storage
    local storageID = findStorage(item.name)
    if storageID then
        moveItemsFromSlots(containerID, storageID, slot)
    end
end
local function sortContainer(id)
    local container = peripheral.wrap(id)
    local items = container.list()

    for slot, item in pairs(items) do
        sortSlot(id, slot, item)
    end
end
local function sortInputContainers()
    for id in pairs(C.Input) do
        sortContainer(id)
    end
end

local function updateInterface(id, expectedItems)
    local items = peripheral.wrap(id).list()
    if n.isEquel(items, expectedItems) then return end

    for slot, item in pairs(items) do
        local expecteditem = expectedItems[slot]
        if not expecteditem or item.name ~= expecteditem.name then
            sortSlot(id, slot, item)
        end
    end
    for slot, expecteditem in pairs(expectedItems) do
        local item = items[slot]
        local shortage = expecteditem.count - (item and item.count or 0)

        if shortage > 0 then
            pullFromBulk(id, id, expecteditem.name, shortage)
        end
    end
end
local function updateBulkInterface(id)
    local sortedBulkItems = sfr.sortItems(C.BulkInterface[id].items)

    local expectedItems = {}
    for i, v in pairs(sortedBulkItems) do
        expectedItems[i] = {
            name = v.id,
            count = math.min(v.count, ItemDetails[v.id].maxCount)
        }
    end
    updateInterface(id, expectedItems)
end
local function updateBulkInterfaces()
    for id in pairs(C.BulkInterface) do
        updateBulkInterface(id)
    end
end


--MAP

local function printSucces(succesCount, failCount, totalCount)
    if not succesCount then n.printRight('Done', colors.green) return end
    if not failCount then 
        if totalCount then 
            failCount = totalCount - succesCount
        else
            n.printRight(tostring(succesCount), colors.green) 
            return 
        end
    end

    local succesStr = tostring(succesCount)
    local failStr = tostring(failCount)

    n.setCursorX(n.termWith - succesStr:len() - failStr:len())
    n.write(succesStr, colors.green)
    write(' ')
    n.write(failStr, colors.red)
end
local function mapItemDetails(ir)
    write('Mapping item details..')
    local itemIDs = ir.list('item')
    
    local details = {}
    for _, id in ipairs(itemIDs) do
        local success, describe = pcall(function() 
            return ir.describe('item', id) 
        end)
        if not success then
            printError('Failed to describe item: ' .. id)
        end

        details[id] = describe and {
            displayName = describe.displayName or id, --string.gsub(describe.displayName, "§.", ""),
            maxCount = describe.maxCount,
            tags = describe.tags
        } or {
            displayName = id,
            maxCount = 64,
            tags = {}
        }
    end

    printSucces(n.getTableLength(details), nil, #itemIDs)
    return details
end
ItemDetails = mapItemDetails(informativeRegistry)


local function mapRecipe(id, data)
    local grid = {}

    if data.type == 'minecraft:crafting_shaped' then
        for r, row in ipairs(data.pattern) do
            for c = 1, #row do
                local char = row:sub(c, c)
                local slot = (r - 1) * 3 + c
                local input = data.key[char]

                if input and not (input.item or input.tag) then return end
                grid[slot] = data.key[char]
            end
        end
    elseif data.type == 'minecraft:crafting_shapeless' then
        grid = data.ingredients
    else return end

    return {
        id = id,
        grid = grid,
        result = data.result.item,
        resultCount = data.result.count or 1
    }
end
local function mapRecipes(rr)
    write('Mapping crafting recipes..')
    local craftingRecipeIDs = rr.list('crafting')

    local recipes = {}
    for _, id in ipairs(craftingRecipeIDs) do
        local data = rr.getRaw(id)
        if data and data.result then
            local itemID = data.result.item

            if not itemID:find(':') then
                itemID = 'minecraft:' .. itemID
            end

            if not ItemDetails[itemID] then
                n.write('\nRecipe for unknown item: ' .. id .. ' -> ' .. data.result.item, colors.red)
            end
            
            recipes[id] = mapRecipe(id, data)
        end
    end

    printSucces(n.getTableLength(recipes), nil, #craftingRecipeIDs)
    return recipes
end
local Recipes = mapRecipes(recipeRegistry)

local function mapResultRecipeIDs(rr)
    write('Mapping result recipes..')

    local resultRecipeIDs = {}
    for id, data in pairs(Recipes) do
        if not resultRecipeIDs[data.result] then
            resultRecipeIDs[data.result] = {}
        end
        resultRecipeIDs[data.result][id] = data
    end

    printSucces(n.getTableLength(resultRecipeIDs))
    return resultRecipeIDs
end
local ResultRecipeIDs = mapResultRecipeIDs(recipeRegistry)

local AllRecipes

local function getItemsWithTag(tag)
    local itemIDs = {}

    for itemID, details in pairs(ItemDetails) do
        if details.tags[tag] then
            table.insert(itemIDs, itemID)
        end
    end

    return next(itemIDs) and itemIDs or nil
end

local function getTagInputs(rr)
    write('Mapping tag inputs')

    local count = 0
    local YIELD_INTERVAL = 500
    local yieldCount = YIELD_INTERVAL
    local craftingRecipeIDs = rr.list('crafting')
    
    local tagInputs = {}
    for _, id in ipairs(craftingRecipeIDs) do
        local data = rr.getRaw(id)

        local function addTag(tag)
            count = count + 1
            if count == yieldCount then
                n.write('.')
                coroutine.yield()
                yieldCount = yieldCount + YIELD_INTERVAL
            end

            tagInputs[tag] = getItemsWithTag(tag)
        end

        if data and ItemDetails[data.result] then
            if data.type == 'minecraft:crafting_shaped' then
                for _, input in pairs(data.key) do
                    if input.tag then
                        addTag(input.tag)
                    end
                end
            elseif data.type == 'minecraft:crafting_shapeless' then
                for type, id in pairs(data.ingredients) do
                    if type == 'tag' then
                        addTag(id)
                    end
                end
            end
        end
    end

    printSucces(count)
    return tagInputs
end
local AllTagInputs = getTagInputs(recipeRegistry)

local function autoSaveTagInputForTagsWithOneItem()
    write('Autosaving tags with one item..')

    local count = 0

    for tag, itemIDs in pairs(AllTagInputs) do
        if #itemIDs == 1 then
            SavedTagInputs[tag] = itemIDs
            count = count + 1
        end
    end

    printSucces(count)
    save('data/saved_tag_inputs.dat', SavedTagInputs)
end
autoSaveTagInputForTagsWithOneItem()

local function isUsableInput(input, result)
    if input.item == result or (ItemDetails[result] and ItemDetails[result].tags[input.item]) then return end

    if not AllRecipes[result] then return end
    for _, recipe in ipairs(AllRecipes[result]) do
        for _, recipeInput in ipairs(recipe.grid) do
            if recipeInput and (recipeInput.item == input.item or (recipeInput.tag and ItemDetails[input.item].tags[recipeInput.tag])) then
                return recipe
            end
        end
    end
end

local function mapCompactableItems()
    local count = 0
    write('Mapping compactable items..')

    local compactableItems = {}
    for decomp, recipeList in pairs(AllRecipes) do
        for _, decompRecipe in ipairs(recipeList) do
            local comp = decompRecipe.grid[1] and decompRecipe.grid[1].item

            if comp and #decompRecipe.grid == 1 and decompRecipe.resultCount > 1 then
                local compactingRecipe = isUsableInput({item = decomp}, comp)

                if compactingRecipe then
                    compactableItems[decomp] = {
                        comp = comp,
                        factor = decompRecipe.resultCount,
                        compRecipeID = compactingRecipe.id,
                        decompRecipeID = decompRecipe.id,
                    }
                    count = count + 1
                end
            end
        end
    end

    printSucces(count)
    return compactableItems
end
local compactableItems = mapCompactableItems()


local function addNewContainer(id, cType)
    local data = sfr.defaultData[cType] and sfr.defaultData[cType](id) or {}

    C[cType][id] = data
end
local function addAllNewContainers()
    local containersAdded = 0
    write('Adding new containers..')

    for _, id in pairs(Peripherals.containers) do
        if sfr.getContainerType(id) == nil then
            addNewContainer(id, 'Storage')
            n.write('\nFound new container: ' .. id, colors.green)
            containersAdded = containersAdded + 1
        end
    end

    n.printRight(tostring(containersAdded), colors.green)
end
local function removeAllDisconnectedContainers()
    local containersRemoved = 0
    write('Removing disconnected containers..')

    for cType in pairs(C) do
        for id in pairs(C[cType]) do
            if not peripheral.wrap(id) then
                C[cType][id] = nil
                n.write('\nRemoved disconnected container: ' .. id, colors.red)
            end
        end
    end

    n.printRight(tostring(containersRemoved), colors.green)
end
local function changeContainerType(id, newType)
    local oldType = sfr.getContainerType(id)
    if oldType == newType then return end

    addNewContainer(id, newType)
    C[newType][id].name = C[oldType][id].name
    C[oldType][id] = nil

    saveC(oldType)
    saveC(newType)
end


local function getContainerItemCounts(id, dontLog)
    local container = peripheral.wrap(id)

    if not container then
        printError('Failed to wrap container: ' .. id)
        removeAllDisconnectedContainers()
        return {}
    end

    local items = container.list()
    local type = sfr.getContainerType(id)
    local itemCounts = type == 'Storage' and C.Storage[id].items or {}

    if not dontLog then
        write(string.format('Mapping %s.. ', sfr.getContainerName(id)))
    end

    for itemName in pairs(itemCounts) do
        itemCounts[itemName] = 0
    end

    for _, item in pairs(items) do
        local name = item.name
        local count = item.count

        if not itemCounts[name] then 
            itemCounts[name] = 0 
        end
        itemCounts[name] = itemCounts[name] + count
    end
    if not dontLog then
        n.printRight('Done', colors.green)
    end
    
    return itemCounts
end
local function mapBulkItems(id)
    write(string.format('Mapping Bulk %s.. ', sfr.getContainerName(id)))

    local bulks = C.BulkInterface[id].bulks
    local itemCounts = C.BulkInterface[id].items

    --sortContainer(id)

    for itemName in pairs(itemCounts) do
        itemCounts[itemName] = 0
    end

    for _, bulk in pairs(bulks) do
        for name, count in pairs(getContainerItemCounts(bulk, true)) do
            if not itemCounts[name] then 
                itemCounts[name] = 0 
            end
            itemCounts[name] = itemCounts[name] + count
        end
    end

    updateBulkInterface(id)

    n.printRight('Done', colors.green)

    return itemCounts
end
local function mapAllStorageItems()
    addAllNewContainers()
    removeAllDisconnectedContainers()

    if next(C.BulkInterface) then
        for id in pairs(C.BulkInterface) do
            C.BulkInterface[id].items = mapBulkItems(id)
        end
    end
    if next(C.Storage) then
        for id in pairs(C.Storage) do
            C.Storage[id].items = getContainerItemCounts(id)
        end
    end
end


--CRAFT

local function getGridPosSlot(gridPos) 
    if gridPos > 6 then 
        return gridPos + 2
    elseif gridPos > 3 then 
        return gridPos + 1 end
    return gridPos
end

local function getCraftCount(resultCount, recipeResultCount)
    return math.ceil(resultCount / recipeResultCount)
end
local function craftRecipe(recipeID, resultCount)
    local recipe = AllRecipes[result][1] --TODO
    local craftsCount = getCraftCount(resultCount, recipe.resultCount)
    local maxCraftsPerBatch = 3 --TODO

    sortContainer(crafterContainerID)

    
end
local function craftResult(result, resultCount)
    local recipe = AllRecipes[result][1] --TODO
    local crafts = math.ceil(resultCount / recipe.resultCount)
    local maxCraftsPerBatch = 3 --TODO

    sortContainer(crafterContainerID)

    for gridPos, input in pairs(recipe.grid) do
        moveItemsFromAnywhere(crafterContainerID, input.item, maxCraftsPerBatch, getGridPosSlot(gridPos))
    end
    
    
    r.action(crafterID, 'craft')
    sortContainer(crafterContainerID)
end

local function compContainer(id)
    local itemCounts = getContainerItemCounts(id)

    for itemID, count in pairs(itemCounts) do
        local maxCount = ItemDetails[itemID].maxCount

        if count > maxCount and compactableItems[itemID] then
            local compDetails = compactableItems[itemID]
            local comp = compactableItems[itemID].comp
            local factor = compactableItems[itemID].factor

            local craftCount = math.floor((count - maxCount) / factor) + 1
            craftRecipe(compDetails.compRecipeID)
        end
    end
end
local function compAllContainers()
    for id in pairs(C.Storage) do
        compContainer(id)
    end
end


--setup

mapAllStorageItems()
saveAllC()


local listenvars = {
    ItemDetails = ItemDetails,

    AllRecipes = AllRecipes,
    SavedRecipes = SavedRecipes,

    AllTagInputs = AllTagInputs,
    SavedTagInputs = SavedTagInputs,
}
local function listen(id, msg, ptc)
    
    for type in pairs(C) do
        listenvars[type] = C[type]
    end
    
    r.listen(id, msg, ptc, {
        remap = function (id)
            print('Remapping ' .. (id or 'all storage') .. '..')
            if id then 
                local type = sfr.getContainerType(id)
                
                if type == 'Storage' then
                    C.Storage[id].items = getContainerItemCounts(id)
                elseif type == 'BulkInterface' then
                    C.BulkInterface[id].items = mapBulkItems(id)
                end

            else mapAllStorageItems() end

            saveAllC()
        end,

        setC = function (type, value)
            C[type] = value
            saveC(type)
        end,
        setSavedRecipes = function (value)
            SavedRecipes = value
            save('data/saved_recipes.dat', SavedRecipes)
        end,
        setSavedTagInputs = function (value)
            SavedTagInputs = value
            save('data/saved_tag_inputs.dat', SavedTagInputs)
        end,
        
        getContainerItems = getContainerItemCounts,
        changeContainerType = changeContainerType,
        moveItemsFromContainer = moveItemsFromContainers,

        recordNewBulks = function (interfaceID)
            local bulks = C.BulkInterface[interfaceID].bulks

            n.print('Connect new Bulks from bottom to top. Press any key to continue.', colors.yellow)
            while true do
                local event, id = os.pullEvent()

                if event == 'peripheral' then
                    
                    --register new container
                    if sfr.getContainerType(id) then
                        changeContainerType(id, 'Bulk')
                    else
                        addNewContainer(id, 'Bulk')
                    end
                    
                    --add to bulks list
                    table.insert(bulks, id)
                    print((' Connected #%d: %s'):format(#bulks, id))

                elseif event == 'key' then 
                    n.print('\nFinished recording new bulks.', colors.green)
                    saveAllC()
                    break 
                end
            end
        end
    }, listenvars)
end

local function tick()
    sortInputContainers()
    updateBulkInterfaces()
    compAllContainers()
end


local tickTimerID = os.startTimer(TICK_DELAY)

while true do
    local eventData = {os.pullEvent()}
    local event = eventData[1]

    redstone.setOutput('right', true)

    if event == 'timer' and eventData[2] == tickTimerID then
        tick()
        while activeState do
            tick()
            activeState = os.epoch('utc') - lastMovementTime < (ACTIVE_STATE_DURATION * 1000)
            
            speaker.playNote('guitar', 3, 8)
        end

        tickTimerID = os.startTimer(TICK_DELAY)        

    elseif event == 'rednet_message' then
        local id, msg, ptc = table.unpack(eventData, 2)
        print(("C%d sent %s %s"):format(id, ptc, tostring(msg)))
        pretty.pretty_print(msg)
        speaker.playNote('bell', 3)

        listen(id, msg, ptc)

        os.cancelTimer(tickTimerID)
        tickTimerID = os.startTimer(TICK_DELAY)

    elseif event == 'peripheral' then
        Peripherals = n.mapPeripherals()
        addAllNewContainers()

    elseif event == 'peripheral_detach' then
        Peripherals = n.mapPeripherals()
        removeAllDisconnectedContainers()
    end

    redstone.setOutput('right', false)
end