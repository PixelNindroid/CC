local n = require('libs.ninlib')

local buttox = {}
local buttons = {}

function buttox.draw(b, isSelected)
    local _buttonColor = isSelected and b.selectColor or b.buttonColor

    if b.fancy then
        term.setCursorPos(b.x + b.w - 1, b.y)
        n.write('\149', _buttonColor, b.bgColor)

        term.setCursorPos(b.x, b.y + 1)
        n.write(string.rep('\143', b.w - 1) .. '\133', _buttonColor, b.bgColor)
    end

    term.setCursorPos(b.x, b.y)
    n.write(b.text, b.textColor, _buttonColor)
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
        selectColor = opts.selectColor or colors.yellow,
        onClick     = opts.onClick  
    }
    if opts.fancy then
        b.fancy = true
        b.bgColor = opts.bgColor or colors.black
        b.w = b.w + 1
        b.h = b.h + 1
    end

    buttons[name] = b
    buttox.draw(b)
    return b
end

local mouseButtonMap = {
    'left',
    'right',
    'middle'
}
local clicked = {}
function buttox.handleClick(p1, p2, p3)
    local mouseButton = mouseButtonMap[p1]
    local x = p2
    local y = p3

    for _, b in pairs(buttons) do
        if b.onClick and (x >= b.x and x < b.x + b.w) and (y >= b.y and y < b.y + b.h) then
            clicked.b = b
            clicked.mouseButton = mouseButton
            
            return b
        end
    end    
end
function buttox.handleUp()
    if clicked.b then
        clicked.b.onClick(clicked.mouseButton)
    end
end
function buttox.run()
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == 'mouse_click' then
            buttox.handleClick(p1, p2, p3)
        end
    end
end

return buttox