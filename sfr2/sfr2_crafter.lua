local n = require('libs.ninlib')
local r = require('libs.redlib')
local completion = require('cc.completion')
local pretty = require('cc.pretty')

peripheral.find("modem", rednet.open)

--[[write('Hosting..')
rednet.host('SFR2_CRAFTER', 'crafter')
n.printSucces()]]

local controllerID = r.getHostID('SFR2_CONTROLLER')

local registry = r.getVar(controllerID, 'registry')

local craftableDisplayNames = {}
for i, id in ipairs(registry.craftable) do
    print(#registry.itemDetails)
    print(id)
    craftableDisplayNames[i] = registry.itemDetails[id].displayName
end

local a = read(nil, nil, function(text) return completion.choice(text, craftableDisplayNames) end)