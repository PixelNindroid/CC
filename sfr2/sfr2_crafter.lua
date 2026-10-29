local n = require('libs.ninlib')
local r = require('libs.redlib')
local pretty = require('cc.pretty')

peripheral.find("modem", rednet.open)

--[[write('Hosting..')
rednet.host('SFR2_CRAFTER', 'crafter')
n.printSucces()]]

local controllerID = r.getHostID('SFR2_CONTROLLER')

local craftable = r.getVar(controllerID, 'craftable')

pretty.pretty_print(craftable)