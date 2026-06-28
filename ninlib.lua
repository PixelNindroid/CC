local pretty = require('cc.prettyeeeeeEe')
local strings = require('cc.strings')

local n = {}

n.termWith, n.termHeight = term.getSize()


--UTIL

function n.keyFromValue(table, _value)
    if not table then return end

    for key, value in pairs(table) do
        if value == _value then return key end
    end
end
function n.isEven(n)
    return n % 2 == 0
end
function n.listLoop(list, i, dir)
    i = i + dir
    if i > #list then i = 1 end
    if i < 1 then i = #list end
    return i
end
function n.extend(list1, list2)
    for _, v in pairs(list2) do
        table.insert(list1, v)
    end
    return list1
end
function n.listContains(list, value)
    for _, v in pairs(list) do
        if v == value then return true end
    end
    return false
end
function n.keysList(table)
    local list = {}

    for k, _ in pairs(table) do
        list[#list + 1] = k
    end
    
    return list
end
function n.removeDuplicates(list)
    local seen = {}
    local newList = {}
    
    for _, v in ipairs(list) do
        if not seen[v] then
            seen[v] = true
            table.insert(newList, v)
        end
    end

    return newList
end
function n.settleList(list)
    local newList = {}
    for _, v in pairs(list) do
        table.insert(newList, v)
    end
    return newList
end
function n.getMatchingValues(list1, list2)
    local matches = {}

    for _, v in pairs(list1) do
        if n.listContains(list2, v) then
            table.insert(matches, v)
        end
    end

    return matches
end
function n.isEquel(t1, t2)
    if t1 == t2 then return true end
    for k1, v1 in pairs(t1) do
        if not t2[k1] or t2[k1] ~= v1 then return false end
    end
    for k2, v2 in pairs(t2) do
        if not t1[k2] then return false end
    end
    return true
end
function n.filterList(list, keysList)
    local filteredList = {}

    for _, key in pairs(keysList) do
        table.insert(filteredList, list[key])
    end

    return filteredList
end

function n.mapPeripherals(modem)
    local names = modem and modem.getNamesRemote() or peripheral.getNames()
    local map = {}

    for _, name in ipairs(names) do
        local type = peripheral.getType(name)..'s'

        if type == 'modems' then
            if peripheral.wrap(name).isWireless() then
                type = 'wirelessModems'
            end

        elseif string.find(type, ':') then
            type = 'containers'
        end

        if map[type] then
            table.insert(map[type], name)
        else
            map[type] = {name}
        end
    end

    return map
end


--TERM

function n.getCursorX()
    local x, _ = term.getCursorPos()
    return x
end
function n.getCursorY()
    local _, y = term.getCursorPos()
    return y
end

function n.setCursorX(x)
    term.setCursorPos(x, n.getCursorY())
end
function n.setCursorY(y)
    term.setCursorPos(n.getCursorX(), y)
end

function n.write(text, color, bg)
    if type(color) == 'number' then term.setTextColor(color) end
    if type(bg) == 'number' then term.setBackgroundColor(bg) end

    local space = n.termWith - n.getCursorX() + 1
    if #text > space then text = strings.ensure_width(text, space) end
    write(text)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
end
function n.print(text, color)
    n.write(text, color)
    write('\n')
end
function n.writeRight(text, color)
    n.setCursorX(n.termWith - string.len(text) + 1)
    n.write(text, color)
end
function n.printRight(text, color)
    n.writeRight(text, color)
    write('\n')
end


function n.getStripedColor(y)
    return n.isEven(y) == true and colors.gray or colors.black
end
function n.clearStriped(startY, lines)
    if startY then n.setCursorY(startY) else startY = n.getCursorY() end
    if not lines then lines = n.termHeight - startY + 1 end

    local y = startY
    for _ = 1, lines do
        n.setCursorY(y)
        term.setBackgroundColor(n.getStripedColor(y))
        term.clearLine()
        y = y + 1
    end

    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, startY)
end
function n.writeStriped(text, color)
    n.write(text, color, n.getStripedColor(n.getCursorY()))
end


--SETTINGS

local function settingify(tableSettings, prefix)
    local settingifiedSettings = {}

    for name, value in pairs(tableSettings) do
        local fullName = prefix and (prefix .. '.' .. name) or name
        if type(value) == 'table' and next(value) then
            local child = settingify(value, fullName)
            for k, v in pairs(child) do settingifiedSettings[k] = v end
        else
            settingifiedSettings[fullName] = value
        end
    end

    return settingifiedSettings
end
function n.defineSettings(tableDefault)
    local settingifiedDefault = settingify(tableDefault)

    for k, v in pairs(settingifiedDefault) do
        settings.define(k, {default = v})
        --settings.set(k, v)
    end

    write('Defined settings: ')
    pretty.pretty_print(settingifiedDefault)
    settings.save()
end

function n.settingAdd(name, new)
    local old = settings.get(name) or {}
	
    settings.set(name, table.insert(old, new))
end


return n