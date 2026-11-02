local n = require('libs.ninlib')
local r = require('libs.redlib')
local completion = require('cc.completion')
local pretty = require('cc.pretty')

peripheral.find("modem", rednet.open)

local controllerID = r.getHostID('SFR2_CONTROLLER')

local registry = r.getVar(controllerID, 'registry')
local itemMap = r.action(controllerID, 'remap')

local function getMostPlentifulItemForTagInput(tag)
    local itemID
    local count = 0

    for _, id in pairs(registry.itemTags[tag]) do
        if registry.itemDetails[id] then
            local totalCount = registry.itemDetails[id].totalCount
            if totalCount > count then
                itemID = id
                count = totalCount
            end
        end
    end

    return itemID, count
end

local function getItemGrid(grid)
    local itemGrid = {}

    for gridPos, input in pairs(grid) do
        if input.item then
            itemGrid[gridPos] = input.item
        elseif input.tag then
            local itemID, count = getMostPlentifulItemForTagInput(input.tag)
            if itemID then
                itemGrid[gridPos] = itemID
            else
                printError('No item found for tag: ' .. input.tag)
                return
            end
        else
            printError('Invalid input: ' .. pretty.pretty_print(input))
            return
        end
    end

    return itemGrid
end

local function getBestCraftingRecipe(result)
    if not registry.resultCraftingRecipeIDs[result] then
        return
    end
    if #registry.resultCraftingRecipeIDs[result] == 1 then
        return registry.resultCraftingRecipeIDs[result][1]
    end
    local recipeID

    return recipeID
end

local function getGridPosSlot(gridPos)
    if gridPos == 1 then return 1
    elseif gridPos == 2 then return 2
    elseif gridPos == 3 then return 3
    elseif gridPos == 4 then return 5
    elseif gridPos == 5 then return 6
    elseif gridPos == 6 then return 7
    elseif gridPos == 7 then return 9
    elseif gridPos == 8 then return 10
    elseif gridPos == 9 then return 11
end
local function moveItemsToGrid(itemGrid)
    for gridPos, value in pairs(itemGrid) do
        
    end
end


local resultName = read(nil, nil, function(text) return completion.choice(text, registry.craftableDisplayNames) end)
local result = registry.craftable[n.keyFromValue(registry.craftableDisplayNames, resultName)]
print('Result: ' .. result)

