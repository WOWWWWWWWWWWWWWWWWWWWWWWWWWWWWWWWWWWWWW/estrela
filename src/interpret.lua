local interpret

local unicode = "[%z\1-\127\194-\244][\128-\191]*"

interpret = function(state)
    local stack = state.stack
    local terminator = state.terminator

    local buffer = {}

    state:onPushStack(function(object)
        insert(buffer,
               "local " .. object.variable .. " = " .. object:transpile())
    end)

    state.iter = state.iter or state.input:gmatch(unicode)
    local iter = state.iter

    function state.next() return iter() end

    function state.lookFor(character)
        local r = {}
        local tk = iter()
        repeat
            if tk ~= character then
                insert(r, tk)
            else
                break
            end
            tk = iter()
        until not tk
        return concat(r)
    end

    function state.push(str) insert(buffer, str) end

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
            buffer[i] = rep("\t", state.depth) .. v
        end
    elseif stack[1] then
        -- find non-statement
        for _, v in pairs(stack) do
            if not v.statement then
                state:import("debug")
                insert(buffer, "_debug(" .. v.variable .. ")")
                break
            end
        end
    end

    return concat(buffer, "\n")
end

return interpret
