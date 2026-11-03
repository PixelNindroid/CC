local n = require('libs.ninlib')
local r = require('libs.redlib')
local completion = require('cc.completion')
local pretty = require('cc.pretty')

n.setNeonColors()

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
    elseif gridPos == 9 then return 11 end
end
local function moveItemsToGrid(itemGrid)
    for gridPos, itemID in pairs(itemGrid) do
        local slot = getGridPosSlot(gridPos)
        r.action(controllerID, {'moveItemToCrafter', itemID, slot})
    end
end


--[[local resultName = 'Builder' --read(nil, nil, function(text) return completion.choice(text, registry.craftableDisplayNames) end)
local result = registry.craftable[n.keyFromValue(registry.craftableDisplayNames, resultName)]
print('Result: ' .. result)

moveItemsToGrid(getItemGrid(registry.craftingRecipes[getBestCraftingRecipe(result)].grid))]]



local gridStartX = 29
local gridStartY = 7
local slotWidth = 3
local slotHeight = 2

local function drawSlot(x, y, slotColor)
    local bgColor = colors.orange

    term.setCursorPos(x, y)
    n.write('  ', slotColor, slotColor)
    n.write('\149', slotColor, bgColor)

    term.setCursorPos(x, y + 1)
    n.write('\143\143\133', slotColor, bgColor)

end


local function drawEmptyGrid()
    term.setCursorPos(gridStartX - 1, gridStartY - 1)
    n.write('\159' .. string.rep('\143', 3 * slotWidth), colors.black, colors.lightGray)

    for i = 1, 3 * slotHeight do
        term.setCursorPos(gridStartX - 1, gridStartY - 1 + i)
        n.write('\149', colors.black, colors.lightGray)
    end

    

    for y = 0, 2 do
        for x = 0, 2 do
            drawSlot(gridStartX + (x * slotWidth), gridStartY + (y * slotHeight), colors.black)
        end
    end
end
local function drawGrid(itemGrid)
    

    for slot in pairs(itemGrid) do
        local position = slot - 1
        local x = gridStartX + (math.fmod(position, 3) * slotWidth)
        local y = gridStartY + (math.floor(position / 3) * slotHeight)
        drawSlot(x, y, colors.orange)
    end
end



local resultName = 'Builder'
local result = registry.craftable[n.keyFromValue(registry.craftableDisplayNames, resultName)]
local itemGrid = getItemGrid(registry.craftingRecipes[getBestCraftingRecipe(result)].grid)

drawEmptyGrid()
--drawGrid(itemGrid)
