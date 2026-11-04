local n = require('libs.ninlib')
local r = require('libs.redlib')
local m = require('libs.makeup')
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
        local itemDetail = turtle.getItemDetail(i)
        if not itemDetail then --nothing crafted
            return
        elseif turtle.getItemDetail(i).name ~= currentItemGrid[i] then
            ejectCrafterSlot(i)
            return
        end
    end
    ejectCrafterSlot(4)
end



buttox.define('refil', {
    x       = 25,
    y       = 13,
    buttonColor = colors.lightGray,
    onUp    = function()
        moveItemsToGrid(currentItemGrid)
    end
})
buttox.define('craft1', {
    text    = 'c1',
    x       = 31,
    y       = 13,
    buttonColor = colors.lightGray,
    onUp    = function()
        craftAndEject(1)
    end
})
buttox.define('craft8', {
    text    = 'c8',
    x       = 34,
    y       = 13,
    buttonColor = colors.lightGray,
    onUp    = function()
        craftAndEject(1)
    end
})
buttox.define('craftAll', {
    text    = 'All',
    x       = 37,
    y       = 13,
    buttonColor = colors.lightGray,
    onUp    = function()
        craftAndEject()
    end
})


drawEmptyGrid()

--search()

local function formatCount(count) --4 wide
    if count < 1000 then --_999
        return m.txtr(tostring(count), 4, colors.lightGray)
    elseif count < 10000 then --9.9k
        return {m.txt(string.format('%.1f', count / 1000), colors.lightGray), m.txt('k', colors.red)}
    elseif count < 1000000 then --999k
        return {m.txtr(math.floor(count / 1000), 3, colors.lightGray), m.txt('k', colors.red)}
    elseif count < 10000000 then --9.9M
        return {m.txt(string.format('%.1f', count / 1000000), colors.lightGray), m.txt('M', colors.red)}
    else --999M
        return {m.txtr(math.floor(count / 1000000), 3, colors.lightGray), m.txt('M', colors.red)}
    end
end

local function getDisplayItemList()
    local list = {}

    for itemID, v in pairs(itemMap) do
        table.insert(list, {
            itemID = itemID,
            count = v.totalCount,
            display = {formatCount(v.totalCount), ' ' .. registry.itemDetails[itemID].displayName}
        })
    end

    table.sort(list, function (a, b)
        return a.count < b.count
    end)

    print('WWWWWWWWWWWWWWWWWWWWWWWWWWW')
    return list
end
local function displayList(list, x, y, w, h)
    
    for i = 1, h do
        term.setCursorPos(x, y + h - 1)
        m.exe(list[i])
    end
end
displayList(getDisplayItemList(), 1, 3, 27, 10)

local textInputX = 1
local textInputY = 1
local typed = ''
local function handleTyping(event, p1)
    if event == 'char' then
        typed = typed .. p1
    elseif event == 'key' then
        if p1 == keys.backspace then
            if #typed > 0 then
                typed = string.sub(typed, 1, #typed - 1)
            end
        end
    else
        return
    end

    term.setCursorPos(textInputX, textInputY)
    write(typed .. '_')
end

while true do
    local event, p1, p2, p3 = os.pullEvent()
    --print('AAAAAAAAAAAAAAAAAAAAAA')

    buttox.handle(event, p1, p2, p3)
    handleTyping(event, p1)
end

--[[local function search()
    term.setCursorPos(1, 2)
    local resultName = read(nil, nil, function(text) return completion.choice(text, registry.craftableDisplayNames) end)
    local result = registry.craftable[n.keyFromValue(registry.craftableDisplayNames, resultName)]
    local recipe = registry.craftingRecipes[getBestCraftingRecipe(result)]
    local itemGrid = getItemGrid(recipe.grid)
    moveItemsToGrid(itemGrid)
    currentItemGrid = itemGrid
end]]
