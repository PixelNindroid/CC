local n = require('libs.ninlib')

local registry = {}

local informativeRegistry = peripheral.find('informative_registry')
local recipeRegistry = peripheral.find('recipe_registry')

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

    n.printSucces(n.getTableLength(details), nil, #itemIDs)
    return details
end

local function mapCraftingRecipe(id, data)
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
local function mapCraftingRecipes(rr)
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

            if not registry.itemDetails[itemID] then
                n.write('\nRecipe for unknown item: ' .. id .. ' -> ' .. data.result.item, colors.red)
            end
            
            recipes[id] = mapCraftingRecipe(id, data)
        end
    end

    n.printSucces(n.getTableLength(recipes), nil, #craftingRecipeIDs)
    return recipes
end
local function mapResultCraftingRecipeIDs(rr)
    write('Mapping result recipes..')

    local resultRecipeIDs = {}
    local craftable = {}
    local craftableDisplayNames = {}
    for id, data in pairs(registry.craftingRecipes) do
        if ItemDetails[data.result] then
            if not resultRecipeIDs[data.result] then
                resultRecipeIDs[data.result] = {}
            end
            table.insert(resultRecipeIDs[data.result], id)

            table.insert(craftable, data.result)
            table.insert(craftableDisplayNames, registry.itemDetails[data.result].displayName)
        end
        
    end

    n.removeDuplicates(craftable)

    n.printSucces(n.getTableLength(resultRecipeIDs))
    return resultRecipeIDs, craftable, craftableDisplayNames
end

if informativeRegistry then
    registry.itemDetails = mapItemDetails(informativeRegistry)

    if recipeRegistry then
        registry.craftingRecipes = mapCraftingRecipes(recipeRegistry)
        registry.resultCraftingRecipeIDs, registry.craftable, registry.craftableDisplayNames = mapResultCraftingRecipeIDs(recipeRegistry)
    end
end


return registry