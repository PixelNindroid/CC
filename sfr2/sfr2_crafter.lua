local n = require('libs.ninlib')
local r = require('libs.redlib')
local buttox = require('libs.buttox')
local completion = require('cc.completion')
local pretty = require('cc.pretty')
local strings = require('cc.strings')

n.setNeonColors()

peripheral.find("modem", rednet.open)

local controllerID = r.getHostID('SFR2_CONTROLLER')

local registry = r.getVar(controllerID, 'registry')
local itemMap = r.action(controllerID, 'remap')


--GUI

local gridStartX = 29
local gridStartY = 7
local slotWidth = 3
local slotHeight = 2

local function getSlotDrawPos(slot)
    local x = gridStartX + (math.fmod(slot - 1, 3) * slotWidth)
    local y = gridStartY + (math.floor((slot - 1) / 3) * slotHeight)

    return x, y
end
local function drawEmptyGridSlot(slot, slotColor)
    local bgColor = colors.gray
    local x, y = getSlotDrawPos(slot)

    term.setCursorPos(x, y)
    n.write('  ', nil, slotColor)
    n.write('\149', slotColor, bgColor)

    term.setCursorPos(x, y + 1)
    n.write('\143\143\133', slotColor, bgColor)
end
local function drawEmptyGrid()
    term.setCursorPos(gridStartX - 1, gridStartY - 1)
    n.write('\159' .. string.rep('\143', 3 * slotWidth), colors.black, colors.gray)

    for i = 1, 3 * slotHeight do
        term.setCursorPos(gridStartX - 1, gridStartY - 1 + i)
        n.write('\149', colors.black, colors.gray)
    end

    for slot = 1, 9 do
        drawEmptyGridSlot(slot, colors.black)
    end
end


--CRAFTING

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

    for slot, input in pairs(grid) do
        if input.item then
            itemGrid[slot] = input.item
        elseif input.tag then
            local itemID, count = getMostPlentifulItemForTagInput(input.tag)
            if itemID then
                itemGrid[slot] = itemID
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

local function getCrafterSlot(slot)
    if slot == 1 then return 1
    elseif slot == 2 then return 2
    elseif slot == 3 then return 3
    elseif slot == 4 then return 5
    elseif slot == 5 then return 6
    elseif slot == 6 then return 7
    elseif slot == 7 then return 9
    elseif slot == 8 then return 10
    elseif slot == 9 then return 11 end
end
local function moveItemsToGrid(itemGrid)
    for slot, itemID in pairs(itemGrid) do
        local crafterSlot = getCrafterSlot(slot)
        r.action(controllerID, {'moveItemToCrafter', itemID, crafterSlot})

        local x, y = getSlotDrawPos(slot)

        buttox.define('slot_' .. slot, {
            x       = x,
            y       = y,
            text    = strings.ensure_width(registry.itemDetails[itemID].displayName, 2),
            fancy   = true,
            group   = 'slot',
            data    = {itemID = itemID, slot = slot},
            onClick = function ()
                local slotButtons = buttox.getButtonsInGroup('slot')
                for _, b in pairs(slotButtons) do
                    if b.data.itemID == itemID and b.data.slot ~= slot then
                        buttox.draw(b, true)
                    end
                end
            end
        })
    end
end

local function ejectCrafterSlot(crafterSlot)
    turtle.select(crafterSlot)
    turtle.drop(crafterSlot)
end

local currentItemGrid
local function craftAndEject(limit)
    turtle.craft(limit)

    for i = 1, 3 do
        if turtle.getItemDetail(i).name ~= currentItemGrid[i] then
            ejectCrafterSlot(i)
            return
        end
    end
    ejectCrafterSlot(4)
end

local function search()
    term.setCursorPos(1, 2)
    local resultName = read(nil, nil, function(text) return completion.choice(text, registry.craftableDisplayNames) end)
    local result = registry.craftable[n.keyFromValue(registry.craftableDisplayNames, resultName)]
    local recipe = registry.craftingRecipes[getBestCraftingRecipe(result)]
    local itemGrid = getItemGrid(recipe.grid)
    moveItemsToGrid(itemGrid)
    currentItemGrid = itemGrid
end

buttox.define('craft1', {
    text    = 'C1',
    x       = 30,
    y       = 13,
    onUp    = function(b, mouseButton)
        craftAndEject(1)
    end
})
buttox.define('craftAll', {
    text    = 'All',
    x       = 35,
    y       = 13,
    onUp    = function(b, mouseButton)
        craftAndEject()
    end
})


drawEmptyGrid()




while true do
    local event, p1, p2, p3 = os.pullEvent()

    if event == 'mouse_click' then
        buttox.handleClick(p1, p2, p3)
    elseif event == 'mouse_up' then
        buttox.handleUp()
    end
end