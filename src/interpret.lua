local interpret

local commands = {}
local function add(symbol, description, f)
    assert(#commands < 256, "no more commands allowed") -- TODO: Multi-symbol commands
    if type(symbol) ~= "table" then symbol = {symbol} end

    for _, alias in pairs(symbol) do
        commands[alias] = {description = description, f = f}
    end
end

local insert = table.insert
local gsub = string.gsub
do
    -- Constants
    add("⒑", "Push 10 to stack", function(state)
        local r = {type = "number"}
        function r:transpile() return 10 end
        state:pushStack(r)
    end)

    -- Numeric literals
    for i = 0, 9 do
        add(tostring(i), "Numeric literal " .. i, function(state)
            local stack = state.stack
            local head = stack[1]

            if head.type == "number" and head.concatable then
                head.v = head.v * 10 + i
            else
                local r = {type = "number", v = v, concatable = true}
                function r:transpile() return self.v end
                state:pushStack(r)
            end
        end)
    end

    -- String literals
    local function pushstring(state, v)
        local r = {type = "string", v = v}

        function r:transpile()
            local replace = {
                ['"'] = '\\"',
                ['\t'] = '\\t',
                ['\r'] = '\\r',
                ['\n'] = '\\n'
            }

            local v = self.v
            for from, to in pairs(replace) do v = gsub(v, from, to) end

            return '"' .. v .. '"'
        end

        state:pushStack(r)
    end

    add({'`', '`'}, "String literal",
        function(state) pushstring(state, state.lookFor(state.currentMark)) end)

    -- Operators

    for _, v in pairs({
        {"+", "Addition"}, {"-", "Subtraction"}, {"*", "Multiplication"},
        {"/", "Division"}, {"^", "Raise to power"}
    }) do
        add(v[1], v[2] .. " Operator", function(state)
            local lhs, rhs = state:popStack(2)

            local r = {type = "binop", lhs = lhs, rhs = rhs}
            function r:transpile()
                return self.lhs:transpile() .. " " .. v[1] .. " " ..
                           self.rhs:transpile()
            end

            state:pushStack(r)
        end)
    end
end

local gmatch = string.gmatch
local concat = table.concat
interpret = function(state)
    local stack = state.stack
    local buffer = {}

    state:onPushStack(function(object)
        insert(buffer,
               "local " .. object.variable .. " = " .. object:transpile())
    end)

    local iter = gmatch(state.input, "[%z\1-\127\194-\244][\128-\191]*")

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

    function state.next() return iter() end

    local tk = iter()
    assert(tk, "file is empty")
    repeat
        state.currentMark = tk

        local command = commands[tk]
        assert(command, "unexpected token `" .. tk .. "`")
        command.f(state)

        tk = iter()
    until not tk

    if stack[1] then insert(buffer, "print(" .. stack[1].variable .. ")") end

    return concat(buffer, "\n")
end

return interpret
