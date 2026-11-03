local n = require('libs.ninlib')

local buttox = {}
local buttons = {}

function buttox.draw(b, isSelected)

    if b.fancy then
        term.setCursorPos(b.x + b.w, b.y)
        n.write('\149', b.buttonColor, b.bgColor)

        term.setCursorPos(b.x, b.y + 1)
        n.write(string.rep('\143', b.w) .. '\133', isSelected and b.selectColor or b.buttonColor, b.bgColor)
    end

    term.setCursorPos(b.x, b.y)
    n.write(b.text, b.textColor, isSelected and b.selectColor or b.buttonColor)
end

function buttox.define(name, opts)
    local label = opts.label or name
    local b = {
        name        = name,
        text        = label,
        x           = opts.x or 1,
        y           = opts.y or 1,
        w           = string.len(label),
        h           = 1,
        textColor   = opts.textColor or colors.white,
        buttonColor = opts.buttonColor or colors.orange,
        selectColor = opts.selectColor or colors.yellow
    }
    if opts.fancy then
        b.fancy = true
        b.bgColor = opts.bgColor or colors.black
        b.w = b.w + 1
        b.h = b.h + 1
    end

    buttox.draw(b)
    return b
end

return buttox