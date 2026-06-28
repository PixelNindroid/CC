local n = require('libs.ninlib')
local pretty = require('cc.pretty')

local m = {}


--ENCODE

function m.txt(text, color)
    return {
        text = text, 
        color = color
    }
end
function m.txtr(text, n, color) 
    return m.txt(string.format('%'..n..'s', text), color)
end
function m.noOpt()
    local args = {...}
    return n.extend(args, {noOpt = true})
end
function m.empty()
    return {
        text = '',
        noOpt = true
    }
end
function m.multiv(name, current, values, altValues)
    local currentWithColor

    for _, v in pairs(altValues or values) do
        if v.text == current then
            currentWithColor = v
            break
        end
    end
    
    return {
        { 
            name,
            m.txt(': ', colors.lightGray),
            currentWithColor
        },
        multivName = name,
        values = values,
        altValues = altValues
    }
end

function m.spacy(options)
    local newOptions = {}

    for _, v in ipairs(options) do
        if #newOptions > 0 then table.insert(newOptions, m.empty()) end
        table.insert(newOptions, v)
    end

    return newOptions
end


--DECODE

function m.exe(var)

    if type(var) == 'string' then
        n.writeStriped(var)

    elseif var[1] then
        for _, v in ipairs(var) do m.exe(v) end

    else --type(var) == 'thingy' then
        n.writeStriped(var.text, var.color)
    end
end
function m.toString(var)

    if type(var) == 'string' then
        return var

    elseif var.text then
        return var.text

    else
        local str = ''
        for _, v in ipairs(var) do
            str = str .. m.toString(v)
            --if i == 0 and var.values then str = str .. ': ' end
        end
        return str
    end
end

function m.nextOpt(list, i, dir)
    repeat i = n.listLoop(list, i, dir)
    until list[i].noOpt ~= true

    return i
end


return m