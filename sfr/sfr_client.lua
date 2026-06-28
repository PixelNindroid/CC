local sfr = require('libs.sfrlib')
local n = require('libs.ninlib')
local r = require('libs.redlib')
local m = require('libs.makeup')
local pretty = require('cc.pretty')
local strings = require('cc.strings')
C = sfr.C

local KEYBIND_NAMES = {'up', 'down', 'left', 'right', 'select', 'back', 'alt', 'search'}

n.defineSettings({
    request_container = '',
    recent_requests = {},
    keybinds = {
        up = keys.w,
        down = keys.s,
        left = keys.a,
        right = keys.d,
        back = keys.b,
        select = keys.enter,
        alt = keys.leftAlt,
        search = keys.tab
    }
})

local sfrColors = {
    orange = 0xff5a12,
    white = 0xefeefd,
    black = 0x262626,
    gray = 0x2a2a2a,
    lightGray = 0xb3afbb,
    red = 0xe11c38,
    green = 0x10e350,
    blue = 0x3070ff,
    purple = 0xc46afc,
    cyan = 0x12dee5,
    brown = 0xb24a21,
    yellow = 0xdbdc40
}
for name, hex in pairs(sfrColors) do
    term.setPaletteColor(colors[name], hex)
    n.write(' ', nil, colors[name])
end
write('\n\n')

peripheral.find("modem", rednet.open)
ServerID = r.getHostID('SFR_SERVER')

local function cclear()
    term.clear()
    term.setCursorPos(1, 1)
end
local function clearAndTitle(title)
    local titleStart = (n.termWith - string.len(title)) / 2
    local rep = string.rep('-', titleStart - 3)

    cclear()
    n.write(string.format('%s{  %s  }%s', rep, title, rep), colors.orange)
    n.print(n.isEven(string.len(title)) and '-' or '', colors.orange)
end

local function numberToStacks(number, maxCount)
    local stacks = math.floor(number / maxCount)
    local items = math.fmod(number, maxCount)

    return stacks, items
end


--MAP

local function getC(type)
    C[type] = r.getVar(ServerID, type)
end
local function getAllC()
    for type in pairs(C) do
        getC(type)
    end
end
local function setC(type)
    r.action(ServerID, {'setC', type, C[type]})
end

getAllC()
local ItemDetails = r.getVar(ServerID, 'ItemDetails')

local AllRecipes = r.getVar(ServerID, 'AllRecipes')
local SavedRecipes = r.getVar(ServerID, 'SavedRecipes')

local AllTagInputs = r.getVar(ServerID, 'AllTagInputs')
local SavedTagInputs = r.getVar(ServerID, 'SavedTagInputs')

local function getAllStorageAndBulkItems()
    local items = {}

    for _, cType in ipairs({'BulkInterface', 'Storage'}) do
        for _, data in pairs(C[cType]) do
            for itemName, count in pairs(data.items) do
                items[itemName] = count
            end
        end
    end

    return items
end
local function getContainerItems(containerID)
    return sfr.getContainerData(containerID).items or r.action(ServerID, {'getContainerItems', containerID})
end


local function pause()
    term.setCursorPos(1, n.termHeight)
    n.writeRight('Press any key to continue', colors.lightGray)

    local _, key = os.pullEvent('key')
    term.scroll(-1)
    return key
end


--MENU FRAMEWORK

local menu = {}

function menu.nothing(title)
    clearAndTitle(title)
    n.write('\n\tNothing here :)', colors.lightGray)
    pause()
end
function menu.confirm(title)
    local opt = menu.select(title, {
        m.txt('Yes', colors.green),
        m.txt('No', colors.red)
    })
    return opt == 'Yes'
end
function menu.read(title)
    clearAndTitle(title)
    write('> ')
    local msg = read()

    return msg
end
do --select menu
    local verticalOffset = 2
    local maxPageLength = n.termHeight - verticalOffset
    local lastSelectedMap = {}


    local function pagify(list, maxPageLength)
        local pages = {}
        local page = {}

        for i, v in pairs(list) do
            table.insert(page, v)
            if i % maxPageLength == 0 or i == #list then
                table.insert(pages, page)
                page = {}
            end
        end

        return pages
    end
    
    function menu.select(title, options, altOptions)
        if next(options) == nil then menu.nothing(title) return end

        local originalOptions = altOptions or options

        local pages
        local page
        local currentPage = 1
        local currentRow = 1

        local searchString = ''
        local matches = {}
        local isSearching = false

        local altPages
        local altPage
        local showAltOptions = false

        if lastSelectedMap[title] then
            for i, opt in ipairs(options) do
                if m.toString(opt) == m.toString(lastSelectedMap[title]) then
                    currentRow = i
                    break
                end
            end
        end

        local function generatePages(matchingOptions, matchingAltOptions)
            pages = pagify(matchingOptions or options, maxPageLength)
            if altOptions then altPages = pagify(matchingAltOptions or altOptions, maxPageLength) end
        end

        local function renderPages()

            n.clearStriped(1 + verticalOffset)

            for row, line in pairs(showAltOptions and altPage or page) do
                term.setCursorPos(4, row + verticalOffset)
                m.exe(line)
            end
            term.setCursorPos(1, currentRow + verticalOffset)
            n.write('>')

            if #pages > 1 then
                n.setCursorY(n.termHeight)
                n.writeRight(string.format('P%d/%d', currentPage, #pages), colors.lightGray)
            end
        end

        local function setRow(r)
            term.setCursorPos(1, currentRow + verticalOffset)
            n.writeStriped(' ')
            term.setCursorPos(1, r + verticalOffset)
            n.writeStriped('>')
            
            currentRow = r
        end
        local function setPage(p)
            page = pages[p]
            if altOptions then altPage = altPages[p] end

            currentPage = p

            renderPages()
            if currentRow > #page then setRow(#page) end
        end

        local function select()
            local selectedTxt = showAltOptions and altPage[currentRow] or page[currentRow]
            term.setCursorPos(1, currentRow + verticalOffset)
            n.writeStriped(' > ' .. m.toString(selectedTxt), colors.lightGray)
            os.pullEvent('key_up')
            n.setCursorX(1)
            m.exe({'>  ', selectedTxt})
            sleep(0.1)

            local optTxt = altOptions and altPage[currentRow] or page[currentRow]
            local opt = m.toString(optTxt)
            local i = n.keyFromValue(originalOptions, optTxt)
            print(opt, i)

            if not title:find('?') then --don't save confirm menus
                lastSelectedMap[title] = optTxt
            end

            if options[i].values then --multivalue
                local title = m.toString(options[i])
                local _, j = menu.select(title, options[i].values, options[i].altValues) -- opt returns ""

                local newValue = j and (options[i].altValues and options[i].altValues[j] or m.toString(options[i].values[j]))
                return options[i].multivName, i, newValue
            end

            return opt, i
        end
        local function toggleAltOptions()
            if altOptions then 
                showAltOptions = not showAltOptions 
                renderPages()
            end
        end

        local function getMatches()
            matches = {}

            for i, line in ipairs(showAltOptions and altOptions or options) do
                if string.match(string.upper(m.toString(line)), searchString) then
                    table.insert(matches, i)
                end
            end

            table.sort(matches, function (a, b)
                local aText = string.upper(m.toString(showAltOptions and altOptions[a] or options[a]))
                local bText = string.upper(m.toString(showAltOptions and altOptions[b] or options[b]))
                
                local aStartsWithSearch = string.find(aText, searchString, 1, true) == 1
                local bStartsWithSearch = string.find(bText, searchString, 1, true) == 1
                
                if aStartsWithSearch == bStartsWithSearch then
                    return a < b
                end
                
                return aStartsWithSearch
            end)
        end
        local function renderSearch()
            n.clearStriped(2, 1)

            if searchString ~= '' or isSearching then
                n.write(' Search: ', colors.lightGray)
                write(searchString)

                if isSearching then
                    n.write('_', colors.lightGray)

                    if matches then
                        n.writeRight(#matches .. ' results', colors.lightGray)
                    end
                end
            end
        end
        local function renderMatches()
            n.clearStriped(1 + verticalOffset)
            for row, optIndex in ipairs(matches) do
                local line = showAltOptions and altOptions[optIndex] or options[optIndex]
                
                term.setCursorPos(4, row + verticalOffset)
                m.exe(line)

                if n.getCursorY() == n.termHeight then break end
            end
        end
        local function search()
            isSearching = true
            renderSearch()

            while true do
                local event, arg = os.pullEvent()

                if event == 'char' then
                    searchString = searchString .. string.upper(arg)
                elseif event == 'key' then
                    if arg == keys.backspace then
                        if #searchString > 0 then
                            searchString = string.sub(searchString, 1, #searchString - 1)
                        end

                    elseif arg == keys.enter then
                        isSearching = false

                        if #matches == 0 then break end
                        if #matches == 1 then 
                            local i = matches[1]
                            local opt = m.toString(altOptions and altOptions[i] or options[i])
                            return opt, i
                        end

                        generatePages(n.filterList(options, matches), altOptions and n.filterList(altOptions, matches))

                        break

                    elseif arg == settings.get('keybinds.alt') then toggleAltOptions()
                    elseif arg == settings.get('keybinds.search') then 
                        isSearching = false

                        searchString = ''
                        generatePages()

                        break
                    end
                end

                getMatches()
                renderSearch()
                renderMatches()
            end

            renderSearch()
            setPage(1)
            setRow(1)
        end
        
        clearAndTitle(title)
        renderSearch()
        generatePages()
        setPage(currentPage)
        setRow(currentRow)

        while true do
            local _, key = os.pullEvent('key')

            if key == settings.get('keybinds.up') then setRow(m.nextOpt(page, currentRow, -1))
            elseif key == settings.get('keybinds.down') then setRow(m.nextOpt(page, currentRow, 1))
            elseif key == settings.get('keybinds.left') then setPage(n.listLoop(pages, currentPage, -1))  
            elseif key == settings.get('keybinds.right') then setPage(n.listLoop(pages, currentPage, 1))
            elseif key == settings.get('keybinds.alt') then toggleAltOptions()
            elseif key == settings.get('keybinds.back') then return nil
            elseif key == settings.get('keybinds.select') then return select()
            elseif key == settings.get('keybinds.search') then 
                local opt, i = search()
                if opt then return opt, i end
            end
        end
    end
end

local ADD = '+ Add'
local ADD_TXT = m.txt(ADD, colors.green)
function menu.addableSelect(title, options, altOptions)
    table.insert(options, ADD_TXT)
    if altOptions then table.insert(altOptions, ADD_TXT) end

    return menu.select(title, options, altOptions)
end


--SFR MENUS

function menu.main()
    while true do
        local opt = menu.select('MAIN', {
            m.txt('Request', sfr.colors.Output),
            m.empty(),
            'Items',
            'Containers',
            'Remap',
            m.empty(),
            'Recipes',
            'Tag Inputs',
            m.empty(),
            'Settings',
            m.empty(),
            m.txt('Exit', colors.red)
        })
        if opt == 'Request' then
            menu.recentRequests()
            
        elseif opt == 'Items' then
            menu.items('all items', sfr.sortItems(getAllStorageAndBulkItems()))

        elseif opt == 'Containers' then
            menu.allContainers()

        elseif opt == 'Remap' then
            cclear()
            r.action(ServerID, 'remap')
            getAllC()
            print('Done')
            pause()

        elseif opt == 'Recipes' then
            menu.recipeResults()

        elseif opt == 'Tag Inputs' then
            menu.tagInputs()

        elseif opt == 'Settings' then
            menu.settings()
        else
            if menu.confirm('Exit?') then 
                cclear()
                break 
            end
        end
    end
end

local function getContainerTypesTxt()
    local types = {}

    for i, type in ipairs(sfr.types) do
        types[i] = m.txt(type, sfr.colors[type])
    end

    return types
end
local function getContainerNameTxt(id)
    return m.txt(sfr.getContainerName(id), sfr.colors[sfr.getContainerType(id)])
end
local function getContainerNamesTxt(IDs)
    local names = {}

    for _, id in ipairs(IDs) do
        table.insert(names, getContainerNameTxt(id))
    end
    
    return names
end
function menu.containers(title, containerIDs)
    local opt = menu.select(title, getContainerNamesTxt(containerIDs), containerIDs)
    if opt == nil then return 'break' end
    menu.containerOptions(opt)
end
function menu.allContainers()
    while true do
        local containerIDs = {}
        for _, type in ipairs(sfr.types) do
            local unsortedContainerIDs = {}

            for id in pairs(C[type]) do
                table.insert(unsortedContainerIDs, id)
            end
            table.sort(unsortedContainerIDs, function (a, b)
                local aNamed = C[type][a].name ~= a
                local bNamed = C[type][b].name ~= b

                if aNamed == bNamed then return a < b end
                if aNamed then return true end
                return false
            end)
            n.extend(containerIDs, unsortedContainerIDs)
        end        

        if menu.containers('Containers', containerIDs) == 'break' then break end
    end
end

function menu.containerOptions(id)
    while true do
        local type = sfr.getContainerType(id)
        local data = sfr.getContainerData(id)
        local name = sfr.getContainerName(id)
        local items = getContainerItems(id)
        local sortedItems = sfr.sortItems(items)

        local options = {
            m.txt('Items', next(sortedItems) and colors.white or colors.lightGray),
            m.multiv('Type', type, m.spacy(getContainerTypesTxt())),
            m.noOpt('id: ', id),
            m.empty(),
            'Remap',
            'Rename',
            m.empty(),
        }
        if type == 'Storage' then
            n.extend(options, {
                m.txt('Whitelisted Items', next(items) and colors.white or colors.lightGray),
                m.txt('Whitelisted Tags', next(data.whitelistedTags) and colors.white or colors.lightGray)
            })

        elseif type == 'BulkInterface' then
            n.extend(options, {
                'Whitelisted Items',
                m.empty(),
                m.txt('Connected Bulks', colors.yellow),
                m.txt('Record new Bulks', colors.yellow),
                m.txt('Disconnect Bulks', colors.red)
            })
        end

        local opt, _, newValue = menu.select(name, options)

        if opt == 'Items' then
            menu.items(name, sortedItems)

        elseif opt == 'Type' and newValue then
            r.action(ServerID, {'changeContainerType', id, newValue})
            getAllC()

        elseif opt == 'Remap' then
            cclear()
            r.action(ServerID, {'remap', id})
            getC(type)
            print('Done')
            pause()

        elseif opt == 'Rename' then
            local newName = menu.read('Rename ' .. name)
            C[type][id].name = newName
            setC(type)
            
        elseif opt == 'Whitelisted Items' then
            menu.whitelistedItems(id)

        elseif opt == 'Whitelisted Tags' then
            menu.whitelistedTags(id)
        
        elseif opt == 'Connected Bulks' then
            menu.connectedBulks(id)

        elseif opt == 'Record new Bulks' then
            menu.recordNewBulks(id)

        elseif opt == 'Disconnect Bulks' then
            if menu.confirm('Disconnect Bulks ?') then
                C.BulkInterface[id].bulks = {}
                setC('BulkInterface')
            end
            menu.connectedBulks(id)
        else break end
    end
end

function menu.connectedBulks(id)
    while true do
        if menu.containers('Connected Bulks', C.BulkInterface[id].bulks) == 'break' then break end
    end
end
function menu.recordNewBulks(id)
    clearAndTitle('Record new Bulks')
    print("\nFollow the server's instructions\n")

    r.action(ServerID, {'recordNewBulks', id})
    pause()
    getC('BulkInterface')

    getAllC()
    menu.connectedBulks(id)
end

local function getItemsTxtOptions(sortedItems)
    local itemList = {}
    local options = {}
    local altOptions = {}

    for _, v in pairs(sortedItems) do
        local id = v.id
        local count = v.count

        if count ~= 0 then
            table.insert(itemList, id)

            print(id)
            local maxCount = ItemDetails[id].maxCount
            local countTxt

            if maxCount == 1 then
                countTxt = m.txtr(count, 5, colors.purple)
            else
                local stacks, rest = numberToStacks(count, maxCount)
                local stackSymbol = maxCount == 64 and 's' or 'z'

                if stacks == 0 then
                    countTxt = m.txtr(rest, 5)
                elseif stacks > 99 then
                    countTxt = {
                        m.txtr(stacks, 3),
                        m.txt(stackSymbol, colors.lightGray),
                        ' '
                    }
                else
                    countTxt = {
                        m.txtr(stacks, 2),
                        m.txt(stackSymbol, colors.lightGray),
                        m.txtr(rest, 2)
                    }
                end
            end
            table.insert(options, {
                countTxt,
                m.txt(':  ', colors.lightGray),
                ItemDetails[id].displayName
            })

            table.insert(altOptions, {
                m.txtr(count, 5), 
                m.txt(':  ', colors.lightGray), 
                id
            })
        end
    end

    return itemList, options, altOptions
end
function menu.items(title, sortedItems)
    while true do
        local itemList, options, altOptions = getItemsTxtOptions(sortedItems)
        
        local opt, i = menu.select(title, options, altOptions)
        if opt == nil then break end

        menu.itemOptions(itemList[i])
    end
end
function menu.itemOptions(itemID)
    local containerID = sfr.getItemLoc(itemID)

    while true do
        local opt = menu.select(ItemDetails[itemID].displayName, {
            m.txt('Request', sfr.colors.Output),
            m.empty(),
            containerID and 'add Tag to Whitelist',
            m.empty(),
            m.txt('Delete', colors.red)
        })
        if opt == 'Request' then 
            menu.request(itemID, containerID)
            
        elseif opt == 'add Tag to Whitelist' then
            menu.addWhitelistedTag(itemID, containerID)
        elseif opt == 'Delete' then
        else break end
    end
end

function menu.recentRequests()
    while true do
        local recentRequests = settings.get('recent_requests')
        local sortedItems = sfr.sortItems(getAllStorageAndBulkItems())

        table.sort(sortedItems, function(a, b)
            local aRecent = n.keyFromValue(recentRequests, a.id) or math.huge
            local bRecent = n.keyFromValue(recentRequests, b.id) or math.huge

            if aRecent == bRecent then 
                return a.count > b.count
            else
                return aRecent < bRecent
            end
        end)

        local itemList, options, altOptions = getItemsTxtOptions(sortedItems)

        local opt, i = menu.select('Request', options, altOptions)
        if opt == nil then break end

        local itemID = itemList[i]
        menu.request(itemID, sfr.getItemLoc(itemID))
    end
end
local DEFAULT_REQUEST_INPUT = '1s'
function menu.request(itemID, from)
    clearAndTitle('Request')
    print('')

    m.exe({
        'Item : ', ItemDetails[itemID].displayName, '\n\n',
        'From : ', getContainerNameTxt(from) or 'N/A', '\n\n',
        'Count: '
    })

    local input = read(nil, nil, function(text) if text == '' then return {DEFAULT_REQUEST_INPUT} end end)
    if input == '' then input = DEFAULT_REQUEST_INPUT end
    local count = 0
    if input:find('s') then
        local stacks, rest = input:match('(.*)s(.*)')
        count = stacks * ItemDetails[itemID].maxCount + (tonumber(rest) or 0)
    else
        count = tonumber(input) or 0
    end

    if count == 0 then return end

    local to = settings.get('request_container') --TODO
    r.action(ServerID, {'moveItemsFromContainer', from, to, itemID, count}) --TODO
    
    local recentRequests = settings.get('recent_requests')

    for i = #recentRequests, 1, -1 do
        if recentRequests[i] == itemID then
            table.remove(recentRequests, i)
        end
    end

    table.insert(recentRequests, 1, itemID)

    while #recentRequests > 34 do
        table.remove(recentRequests)
    end

    -- 4. Save the original table directly
    settings.set('recent_requests', recentRequests)
    settings.save()
end

function menu.whitelistedItems(id)
    while true do
        local containerData = sfr.getContainerData(id)
        local itemNames = {}
        local itemIDs = {}

        for itemID in pairs(containerData.items) do
            table.insert(itemNames, ItemDetails[itemID].displayName)
            table.insert(itemIDs, itemID)
        end

        local _, i = menu.select('Whitelisted Items in ' .. sfr.getContainerName(id), itemNames, itemIDs)
        if not i then break end
        
        if menu.confirm(string.format('Remove %s?', itemNames[i])) then
            containerData.items[itemIDs[i]] = nil
            setC(sfr.getContainerType(id))
        end
        
    end
end
local function sortTags(tags)
    local sortedTags = {}

    for tag in pairs(tags) do
        table.insert(sortedTags, tag)
    end
    table.sort(sortedTags)
    
    return sortedTags
end
function menu.whitelistedTags(id)
    while true do
        local containerData = sfr.getContainerData(id)
        local sortedTags = sortTags(containerData.whitelistedTags)

        print(id)
        local opt = menu.select('Whitelisted Tags in ' .. sfr.getContainerName(id), sortedTags)
        if not opt then break end
        
        if menu.confirm(string.format('Remove %s?', opt)) then
            containerData.whitelistedTags[opt] = nil
            setC(sfr.getContainerType(id))
        end
    end
end
function menu.addWhitelistedTag(itemID, containerID)
    local opt = menu.select('add Tag to Whitelist', sortTags(ItemDetails[itemID].tags))

    if opt then 
        sfr.getContainerData(containerID).whitelistedTags[opt] = true
        setC('Storage')
    end
end


function menu.recipeResults()
    while true do
        local options = {}
        local altOptions = {}

        for result in pairs(AllRecipes) do
            table.insert(altOptions, result)
        end

        table.sort(altOptions, function (a, b)
            local aSavedCount = SavedRecipes[a] and #SavedRecipes[a] or 0
            local bSavedCount = SavedRecipes[b] and #SavedRecipes[b] or 0

            if aSavedCount == bSavedCount then
                return ItemDetails[a] and ItemDetails[a].displayName or a < (ItemDetails[b] and ItemDetails[b].displayName or b)
            end

            return aSavedCount > bSavedCount
        end)

        for _, result in ipairs(altOptions) do
            table.insert(options, m.txt(ItemDetails[result] and ItemDetails[result].displayName or result, SavedRecipes[result] and colors.white or colors.lightGray))
        end

        local opt = menu.select('Recipes', options, altOptions)
        if not opt then break end

        menu.resultRecipes(opt)
    end
end

function menu.priority(title, active, disabled)
    active = active or {}
    disabled = disabled or {}

    local activeCount = #active
    local values = {m.txt('Disabled', colors.red)}

    for i = 1, activeCount + 1 do
        table.insert(values, m.txt('#' .. i, colors.green))
    end
    
    local options = {}
    for i, v in ipairs(active) do
        table.insert(options, m.multiv(v, '#' .. i, values))
    end
    table.sort(disabled)
    for _, v in ipairs(disabled) do
        table.insert(options, m.multiv(v, 'Disabled', values))
    end

    while true do
        local opt, _, newValue = menu.select(title, options, options)
        if not opt then return end

        if newValue then
            if n.listContains(active, opt) then
                table.remove(active, n.keyFromValue(active, opt))
            end
            if newValue ~= 'Disabled' then
                table.insert(active, newValue:sub(2), opt)
            end
            active = n.settleList(active)

            return active
        end
    end
end
function menu.resultRecipes(result)
    while true do
        local active = SavedRecipes[result] or {}
        local disabled = {}

        for _, recipe in ipairs(AllRecipes[result]) do
            if not n.listContains(active, recipe.id) then
                table.insert(disabled, recipe.id)
            end
        end

        local newActive = menu.priority('Recipes: ' .. ItemDetails[result].displayName, active, disabled)
        if not newActive then break end

        SavedRecipes[result] = newActive
        r.action(ServerID, {'setSavedRecipes', SavedRecipes})
    end
end

function menu.tagInputs()
    while true do
        local options = {}
        local altOptions = {}

        for tag, itemIDs in pairs(AllTagInputs) do
            if #itemIDs ~= 1 then
                table.insert(altOptions, tag)
            end
        end

        table.sort(altOptions, function (a, b)
            local aSavedCount = SavedTagInputs[a] and #SavedTagInputs[a] or 0
            local bSavedCount = SavedTagInputs[b] and #SavedTagInputs[b] or 0

            if aSavedCount == bSavedCount then
                return ItemDetails[a] and ItemDetails[a].displayName or a < (ItemDetails[b] and ItemDetails[b].displayName or b)
            end

            return aSavedCount > bSavedCount
        end)

        for _, tag in ipairs(altOptions) do
            table.insert(options, m.txt(tag, SavedTagInputs[tag] and colors.white or colors.lightGray))
        end

        local opt = menu.select('Tag Inputs', options, altOptions)
        if not opt then break end

        menu.tagInputItems(opt)
    end
end

function menu.tagInputItems(tag)
    while true do
        local active = SavedTagInputs[tag] or {}
        local disabled = {}

        for _, itemID in ipairs(AllTagInputs[tag]) do
            if not n.listContains(active, itemID) then
                table.insert(disabled, itemID)
            end
        end

        local newActive = menu.priority('Tag Input: #' .. tag, active, disabled)
        if not newActive then break end

        SavedTagInputs[tag] = newActive
        r.action(ServerID, {'setSavedTagInputs', SavedTagInputs})
    end
end

function menu.settings()
    while true do
        local values = {m.txt('Disabled', colors.red)}
        local altValues = {'Disabled'}
        local current = settings.get('request_container') == '' and 'Disabled' or settings.get('request_container')
        for id in pairs(C.Output) do
            table.insert(values, getContainerNameTxt(id))
            table.insert(altValues, id)
        end

        local opt, _, newValue = menu.select('Settings', {
            m.multiv('Request Container', current, values, altValues),
            'Keybinds'
        })
        if not opt then break end

        if newValue then
            if newValue == 'Disabled' then
                settings.set('request_container', '')
            else
                for id in pairs(C.Output) do
                    if id == m.toString(newValue) then
                        settings.set('request_container', id)
                        break
                    end
                end
            end

            settings.save()

        elseif opt == 'Keybinds' then
            menu.keybinds()
        end
    end
end

function menu.keybinds()
    while true do
        local options = {}

        for _, name in pairs(KEYBIND_NAMES) do
            local key = settings.get('keybinds.' .. name)

            table.insert(options, {
                m.txtr(name:gsub("^%l", string.upper), -6),
                m.txt(':  [', colors.lightGray),
                keys.getName(key),
                m.txt(']', colors.lightGray)
            })
        end

        local _, i = menu.select('Keybinds', options)
        if i == nil then break end

        term.setCursorPos(13, i + 2)
        n.write('[Listening..]', colors.orange)

        settings.set('keybinds.' .. KEYBIND_NAMES[i], pause())
        settings.save()
    end
end

menu.main()