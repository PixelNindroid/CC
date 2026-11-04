local n = require('libs.ninlib')
local m = require('libs.makeup')

local buttox = {}
local widgets = {}

local function drawButton(w)
    local _buttonColor = w.isActive and w.activeColor or w.buttonColor

    if w.fancy then
        term.setCursorPos(w.x + w.w - 1, w.y)
        n.write('\149', _buttonColor, w.bgColor)

        term.setCursorPos(w.x, w.y + 1)
        n.write(string.rep('\143', w.w - 1) .. '\133', _buttonColor, w.bgColor)
    end

    term.setCursorPos(w.x, w.y)
    n.write(w.text, w.textColor, _buttonColor)
end
local function drawList(w)
    for currentH = 1, w.h do
        term.setCursorPos(x, w.y + currentH - 1)

        local i = w.topi + currentH - 1
        m.exe(list[i].display, w.w)
    end
end
function buttox.drawAll()
    for _, w in pairs(widgets) do
        w:draw()
    end
end

local function define(name, w)
    widgets[name] = w
    w:draw()
    return w
end
function buttox.defineButton(name, opts)
    local text = opts.text or name
    local w = {
        type        = 'button',
        draw        = drawButton,
        name        = name,
        text        = text,
        isActive    = opts.isActive or false,
        x           = opts.x or 1,
        y           = opts.y or 1,
        w           = string.len(text),
        h           = 1,
        textColor   = opts.textColor or colors.white,
        buttonColor = opts.buttonColor or colors.orange,
        activeColor = opts.activeColor or colors.yellow,
        onClick     = opts.onClick,  
        onUp        = opts.onUp,
        group       = opts.group,
        data        = opts.data or {}
    }
    if opts.fancy then
        w.fancy = true
        w.bgColor = opts.bgColor or colors.black
        w.w = w.w + 1
        w.h = w.h + 1
    end

    return define(name, w)
end
function buttox.defineList(name, opts)
    local w = {
        type        = 'list',
        draw        = drawList,
        name        = name,
        list        = opts.list or {},
        topi        = opts.topi or 1,
        x           = opts.x or 1,
        y           = opts.y or 1,
        w           = opts.w or 20,
        h           = opts.h or #list,
        onClick     = opts.onClick,
        onUp        = opts.onUp
    }

    return define(name, w)
end

function buttox.getWidget(name)
    return widgets[name]
end
function buttox.getWidgetsInGroup(group)
    local groupButtons = {}

    for _, b in pairs(widgets) do
        if b.group == group then
            table.insert(groupButtons, b)
        end
    end

    return groupButtons
end

function buttox.remove(name)
    if name then
        widgets[name] = nil
    else
        widgets = {}
    end
end
function buttox.removeGroup(group)
    for _, b in pairs(getButtonsInGroup(group)) do
        buttox.remove(b.name)
    end
end


--CLICK

local function inBounds(x, y, w)
    return (x >= w.x and x < w.x + w.w) and (y >= w.y and y < w.y + w.h)
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

        for _, w in pairs(widgets) do
            if inBounds(x, y, w) then
                if w.isActive then w.isActive = true end
                w:draw()

                lastClicked.w = w
                lastClicked.mouseButton = mouseButton

                if w.onClick then
                    w.onClick(w, mouseButton, x, y)
                end
                
                return w
            end
        end    
    elseif event == 'mouse_up' then
        if lastClicked.w then
            if w.isActive then w.isActive = false end
            w:draw()

            if lastClicked.w.onUp then
                lastClicked.w.onUp(lastClicked.w, lastClicked.mouseButton)
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