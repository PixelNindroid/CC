local n = require('libs.ninlib')

local buttox = {}
local buttons = {}

function buttox.draw(b)
    if b.fancy then
        term.setCursorPos(b.x + b.w - 1, b.y
        n.write('\149', b.buttonColor, bgColor))
    end

    term.setCursorPos(b.x, b.y)
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
        clickColor  = opts.clickColor or colors.yellow
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