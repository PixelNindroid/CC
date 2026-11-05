local n = require('libs.ninlib')
local m = require('libs.makeup')

local buttox = {}
local widgets = {}


--DRAW

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
    n.drawRectStriped(w.x, w.y, w.w, w.h)
    for currentH = 1, w.h do
        term.setCursorPos(w.x, w.y + currentH - 1)

        local i = w.topi + currentH - 1
        m.exe(w.list[i] and w.list[i].display or '-', w.w)
    end
end

function buttox.drawAll()
    for _, w in pairs(widgets) do
        w:draw()
    end
end


--DEFINE

function buttox.define(name, opts)
    local w = {
        x           = opts.x or 1,
        y           = opts.y or 1,
        w           = opts.w or 1,
        h           = opts.h or 1,
        isActive    = opts.isActive or true,
        group       = opts.group,
        data        = opts.data or {},

        draw        = opts.draw,
        onClick     = opts.onClick,  
        onUp        = opts.onUp,
        onScroll    = opts.onScroll
    }
    if not w.draw then printError(name .. ' was defined without a draw function') end
    
    widgets[name] = w
    w:draw()
    return w
end
function buttox.defineButton(name, opts)
    local text = opts.text or name
    local buttonOpts = {
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
        buttonOpts.fancy = true
        buttonOpts.bgColor = opts.bgColor or colors.black
        buttonOpts.w = buttonOpts.w + 1
        buttonOpts.h = buttonOpts.h + 1
    end

    return buttox.define(name, buttonOpts)
end

local function scrollList(w, scrollDir)
    local max = #w.list - w.h + 1
    w.topi = math.max(1, math.min(w.topi + scrollDir, max))
    w:draw()
end
function buttox.defineList(name, opts)
    local listOpts = {
        draw        = drawList,
        name        = name,
        list        = opts.list or {},
        topi        = opts.topi or 1,
        x           = opts.x or 1,
        y           = opts.y or 1,
        w           = opts.w or 20,
        h           = opts.h or #list,
        onClick     = opts.onClick,
        onUp        = opts.onUp,
        onScroll    = scrollList
    }

    return buttox.define(name, listOpts)
end

function buttox.getListClickedValue(name, y)
    local w = widgets[name]
    local i = w.topi + (y - w.y)
    local v = w.list[i]

    return v 
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

function buttox.removeWidget(name)
    if name then
        widgets[name] = nil
    else
        widgets = {}
    end
end
function buttox.removeWigetsInGroup(group)
    for _, b in pairs(getButtonsInGroup(group)) do
        buttox.removeWidget(b.name)
    end
end

function buttox.editWidget(name, opts)
    for k, v in pairs(opts) do
        local w = widgets[name]

        w[k] = v
        w:draw()
    end
end


--CLICK

local function inBounds(w, x, y)
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
            if inBounds(w, x, y) then
                if w.isActive then 
                    w.isActive = true
                    w:draw()
                end

                lastClicked.w = w
                lastClicked.mouseButton = mouseButton

                if w.onClick then
                    w.onClick(x, y, mouseButton)
                end
                
                return w
            end
        end    
    elseif event == 'mouse_up' then
        if lastClicked.w then
            local w = lastClicked.w

            if w.isActive then 
                w.isActive = false
                w:draw()
            end

            if w.onUp then
                w.onUp(lastClicked.mouseButton)
            end
        end
    elseif event == 'mouse_scroll' then
        local scrollDir = p1
        local x = p2
        local y = p3

        for _, w in pairs(widgets) do
            if inBounds(w, x, y) and w.onScroll then
                w:onScroll(scrollDir)
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