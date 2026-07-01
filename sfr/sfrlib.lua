local n = require('libs.ninlib')
local pretty = require('cc.pretty')

local C_TYPES = {
    {
        name = 'Storage',
        color = colors.white,
        defaultData = function(id) 
            return {
                items = {},
                whitelistedTags = {}
            }
        end
    },
    {
        name = 'Input',
        color = colors.blue
    },
    {
        name = 'Output',
        color = colors.purple
    },
    {
        name = 'Interface',
        color = colors.cyan,
    },
    {
        name = 'BulkInterface',
        color = colors.brown,
        defaultData = function(id) 
            return {
                bulks = {},
                items = {}
            }
        end
    },
    {
        name = 'Bulk',
        color = colors.yellow
    }
}

local sfr = {
    types = {},
    colors = {},
    defaultData = {},
    path = {},

    C = {}
}

for i, v in ipairs(C_TYPES) do
    local type = v.name

    sfr.types[i] = type
    sfr.colors[type] = v.color
    sfr.defaultData[type] = v.defaultData
    sfr.path[type] = string.format('data/%s.dat', string.lower(type))

    sfr.C[v.name] = {}
end

function sfr.getContainerType(id)
    for type, data in pairs(C) do
        if data[id] then return type end
    end
end
function sfr.getContainerData(id)
    return C[sfr.getContainerType(id)][id]
end
function sfr.getContainerName(id)
    return sfr.getContainerData(id).name or id
end

function sfr.getItemLoc(itemID, cTypes)
    cTypes = cTypes or {'BulkInterface', 'Storage'}
    if type(cTypes) == "string" then cTypes = {cTypes} end

    for _, cType in ipairs(cTypes) do
        for containerID, containerData in pairs(C[cType]) do
            
            if containerData.items[itemID] then
                return containerID
            end
        end
    end
end
function sfr.getSlots(itemID, containerID)
    local slots = {}

    for slot, item in pairs(peripheral.wrap(containerID).list()) do
        if item.name == itemID then table.insert(slots, slot) end
    end

    return slots
end
function sfr.getTagLoc(itemID)
    local tags = ItemDetails[itemID].tags

    for id, data in pairs(C.Storage) do
        term.clear()
        pretty.pretty_print(tags)
        print('e')
        pretty.pretty_print(data.whitelistedTags)
        local matchingTags = n.getMatchingKeys(tags, data.whitelistedTags)
        
        if next(matchingTags) then return id end
    end
end

function sfr.sortItems(items)
    local sortedItems = {}

    for id, count in pairs(items) do
        table.insert(sortedItems, {id = id, count = count})
    end

    table.sort(sortedItems, function(a, b)
        return a.count > b.count
    end)

    return sortedItems 
end

return sfr
