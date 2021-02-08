local interpret

function i(str, state, args) -- Interpolation function
    str = str:gsub("\n", "\n" .. ("\t"):rep(state.depth)):gsub("    ", "\t")
    local result = str:gsub("%$%{(.-)%}", function(n) return args[n] end)

    return result
end

local commands = require "commands"
local count = commands.count
commands = commands.commands

do
    for _, v in pairs({"constants", "operators", "statements", "table"}) do
        require("commands." .. v)
    end
end

print("Interpreter loaded with " .. count() .. " commands")

interpret = function(state)
    local stack = state.stack
    local terminator = state.terminator

    local buffer = {}

    state:onPushStack(function(object)
        table.insert(buffer,
                     "local " .. object.variable .. " = " .. object:transpile())
    end)

    state.iter = state.iter or
                     state.input:gmatch("[%z\1-\127\194-\244][\128-\191]*")
    local iter = state.iter

    function state.next() return iter() end

    function state.lookFor(character)
        local r = {}
        local tk = iter()
        repeat
            if tk ~= character then
                table.insert(r, tk)
            else
                break
            end
            tk = iter()
        until not tk
        return table.concat(r)
    end

    function state.push(str) table.insert(buffer, str) end

    local tk = iter()
    state.currentMark = tk
    assert(tk, "file is empty")

    repeat
        local command = commands[tk]
        if command then command.f(state) end

        tk = iter()
        state.currentMark = tk

        -- ugly hack
        if state.currentNumber and
            (not tk or not commands[tk] or not commands[tk].number) then
            state:pushStack(state.currentNumber)
            state.currentNumber = nil
        end
    until not tk or tk == ")" or tk == terminator

    if state.depth > 0 then
        for i, v in pairs(buffer) do
            buffer[i] = ("\t"):rep(state.depth) .. v
        end
    elseif stack[1] then
        -- find non-statement
        for _, v in pairs(stack) do
            if not v.statement then
                state:import("debug")
                table.insert(buffer, "_debug(" .. v.variable .. ")")
                break
            end
        end
    end

    return table.concat(buffer, "\n")
end

return interpret
