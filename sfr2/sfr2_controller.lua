local n = require('libs.ninlib')
local r = require('libs.redlib')
local grab = require('libs.grab')
local pretty = require('cc.pretty')

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
    local map = {}

    for _, containerID in pairs(peripherals.containers) do
        local container = peripheral.wrap(containerID)
        if container.list then
            for _, v in pairs(container.list()) do
                addToItemMap(map, v.name, v.count, containerID)
            end
        elseif container.items then
            for _, v in pairs(container.items()) do
                addToItemMap(map, v.name, v.count, containerID)
            end
        end
    end

    return map
end

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