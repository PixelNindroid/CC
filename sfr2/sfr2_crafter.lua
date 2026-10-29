local n = require('libs.ninlib')
local r = require('libs.redlib')
local pretty = require('cc.pretty')

peripheral.find("modem", rednet.open)

write('Hosting..')
rednet.host('SFR_CRAFTER', 'sfr_crafter')
n.printSucces()