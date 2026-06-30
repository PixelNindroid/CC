local r = {}


function r.getHostID(ptc)
    local hostID

    print(string.format('Looking for %s..', ptc))

    while not hostID do
        hostID = rednet.lookup(ptc)

        if hostID then
            print(string.format('Found %s at computer #%s', ptc, hostID))
            return hostID
        end

        printError('Cannot find '..ptc)
        sleep(1)
    end
end

function r.confirm(id)
    rednet.send(id, true, 'CONFIRM')
end
local CONFIRMTIMEOUT = 0.2
function r.awaitConfirmation(expectedID)
    local id = rednet.receive('CONFIRM', CONFIRMTIMEOUT)
    if id == expectedID then return true end
end

function r.safeSend(id, msg, ptc)
    while true do
        rednet.send(id, msg, ptc)
        if r.awaitConfirmation(id) then break end

        printError(string.format('%s "%s" wansn\'t confirmed.', ptc, tostring(msg)))
    end
end
function r.get(id, name, getPtc, setPtc)
    r.safeSend(id, name, getPtc)

    while true do
        local _, msg = rednet.receive(setPtc)
        if msg.name == name then
            r.confirm(id)
            return msg.var
        end
    end
end


--APPLICATIONS

function r.action(id, action)
    r.safeSend(id, action, 'ACTION')

    print('Waiting for action result..')
    local _, results = rednet.receive('ACTIONRESULT')
    
    r.confirm(id)
    return table.unpack(results)
end

function r.getVar(id, name)
    return r.get(id, name, 'GETVAR', 'SETVAR')
end
function r.setVar(id, name, var)
    return r.safeSend(id, {name = name, var = var}, 'SETVAR')
end

function r.getSetting(id, name)
    return r.get(id, name, 'GETSETTING', 'SETSETTING')
end
function r.setSetting(id, name, var)
    r.safeSend(id, {name = name, var = var}, 'SETSETTING')
end

function r.log(msg)
    rednet.broadcast(msg, 'LOG')
end


function r.listen(id, msg, ptc, actions, vars)
    
    if ptc == 'ACTION' then
        local actionName, parameters
        if type(msg) == 'table' then
            actionName = msg[1]
            parameters = {table.unpack(msg, 2)}
        else
            actionName = msg
            parameters = {}
        end

        if actions[actionName] then
            r.confirm(id)

            local results = {actions[actionName](table.unpack(parameters))}
            r.safeSend(id, results, 'ACTIONRESULT')
            
        else
            printError('Didn\'t find action '..actionName)
        end
    
    elseif ptc == 'GETVAR' then
        if vars[msg] then
            r.confirm(id)
            r.setVar(id, msg, vars[msg])
        else
            printError('Didn\'t find var '..msg)
        end

    elseif ptc == 'SETVAR' then
        local name = msg.name
        local var = msg.var

        if vars[name] then
            r.confirm(id)
            vars[name] = var
            print('Set ' .. name .. ' to ' .. tostring(var))
        else
            printError('Didn\'t find var '..name)
        end
        
    
    elseif ptc == 'GETSETTING' then
        r.confirm(id)
        r.setSetting(id, msg, settings.get(msg))

    elseif ptc == 'SETSETTING' then
        settings.set(msg.name, msg.var)
        r.confirm(id)
        settings.save()

    else 
        print('Ignored.') 
        return 
    end

    print('Done.')
end


return r