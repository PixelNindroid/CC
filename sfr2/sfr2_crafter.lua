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

local function getBestCraftingRecipe(result)
    if not registry.resultCraftingRecipeIDs[result] then
        return
    end
    if #registry.resultCraftingRecipeIDs[result] == 1 then
        return registry.resultCraftingRecipeIDs[result][1]
    end
end


local resultName = read(nil, nil, function(text) return completion.choice(text, registry.craftableDisplayNames) end)
local result = registry.craftable[n.getKeyFromValue(registry.craftableDisplayNames, resultName)]
print('Result: ' .. result)