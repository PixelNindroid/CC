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
function buttox.drawAll()
    for _, b in pairs(buttons) do
        buttox.draw(b)
    end
end

function buttox.define(name, opts)
    local text = opts.text or name
    local b = {
        name        = name,
        text        = text,
        x           = opts.x or 1,
        y           = opts.y or 1,
        w           = string.len(text),
        h           = 1,
        textColor   = opts.textColor or colors.white,
        buttonColor = opts.buttonColor or colors.orange,
        selectColor = opts.selectColor or colors.yellow,
        onClick     = opts.onClick,  
        onUp        = opts.onUp,
        group       = opts.group,
        data        = opts.data or {}
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

function buttox.getButton(name)
    return buttons[name]
end
function buttox.getButtonsInGroup(group)
    local groupButtons = {}

    for _, b in pairs(buttons) do
        if b.group == group then
            table.insert(groupButtons, b)
        end
    end

    return groupButtons
end

function buttox.remove(name)
    if name then
        buttons[name] = nil
    else
        buttons = {}
    end
end
function buttox.removeGroup(group)
    for _, b in pairs(getButtonsInGroup(group)) do
        buttox.remove(b.name)
    end
end



local mouseButtonMap = {
    'left',
    'right',
    'middle'
}
local lastClicked = {}
function buttox.handle(event, p1, p2, p3)
    if event == 'mouse_click' then
        local mouseButton = mouseButtonMap[p1]
        local x = p2
        local y = p3

        for _, b in pairs(buttons) do
            if (x >= b.x and x < b.x + b.w) and (y >= b.y and y < b.y + b.h) then
                buttox.draw(b, true)

                lastClicked.b = b
                lastClicked.mouseButton = mouseButton

                if b.onClick then
                    b.onClick(b, mouseButton)
                end
                
                return b
            end
        end    
    elseif event == 'mouse_up' then
        if lastClicked.b then
            buttox.draw(lastClicked.b)

            if lastClicked.b.onUp then
                lastClicked.b.onUp(lastClicked.b, lastClicked.mouseButton)
            end
        end
    end
end
function buttox.run()
    while true do
        local _, p1, p2, p3 = os.pullEvent()
        buttox.handle(p1, p2, p3)

    end
end

return buttox