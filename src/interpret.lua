local interpret

local unicode = "[%z\1-\127\194-\244][\128-\191]*"

local commands = {}
local function add(symbol, description, f)
    assert(#commands < 256, "no more commands allowed") -- TODO: Multi-symbol commands
    if type(symbol) ~= "table" then symbol = {symbol} end

    for _, alias in pairs(symbol) do
        commands[alias] = {description = description, f = f}
    end
end

local insert = table.insert
local concat = table.concat
local gsub = string.gsub
local sub = string.sub
local rep = string.rep

do
    -- Constants
    add("⒑", "Push 10 to stack", function(state)
        local r = {}
        function r:transpile() return 10 end
        state:pushStack(r)
    end)

    -- Numeric literals
    for i = 0, 9 do
        add(tostring(i), "Numeric literal " .. i, function(state)
            local stack = state.stack
            local head = stack[1]

            if head and head.concatableNumber then
                head.v = head.v * 10 + i
            else
                local r = {v = i, concatableNumber = true}
                function r:transpile() return self.v end
                state:pushStack(r)
            end
        end)
    end

    -- String literals
    local function pushstring(state, v)
        local r = {v = v}

        function r:transpile()
            local replace = {
                ['"'] = '\\"',
                ['\t'] = '\\t',
                ['\r'] = '\\r',
                ['\n'] = '\\n'
            }

            local v = self.v
            for from, to in pairs(replace) do v = gsub(v, from, to) end

            v = gsub(v, unicode, function(c) return '"' .. c .. '", ' end)
            v = sub(v, 1, -3)
            return '{' .. v .. '}'
        end

        state:pushStack(r)
    end

    add({'`', '`'}, "String literal",
        function(state) pushstring(state, state.lookFor(state.currentMark)) end)

    add("↑", "Print a", function(state)
        local a = state:popStack(1)
        local r = {statement = true, a = a}
        function r:transpile() return "print(" .. self.a.variable .. ")" end

        state:pushStack(r)
    end)

    add("⇑", "Verbose print a", function(state)
        state:import("debug")

        local a = state:popStack(1)
        local r = {statement = true, a = a}
        function r:transpile() return "_debug(" .. self.a.variable .. ")" end

        state:pushStack(r)
    end)

    -- Operators

    -- Binary

    add("⊷", "Prepend b to a", function(state)
        state:import("insert")

        local a, b = state:popStack(1)

        local r = {statement = true, a = a, b = b}
        function r:transpile()
            return "insert(" .. self.a.variable .. ", 1, " .. self.b.variable ..
                       ")"
        end

        state:pushStack(r)
    end)

    add("⊶", "Append b to a", function(state)
        state:import("insert")

        local a, b = state:popStack(1)

        local r = {statement = true, a = a, b = b}
        function r:transpile()
            return "insert(" .. self.a.variable .. ", " .. self.b.variable ..
                       ")"
        end

        state:pushStack(r)
    end)

    for _, v in pairs({
        {"+", "Addition"}, {"-", "Subtraction"}, {"*", "Multiplication"},
        {"/", "Division"}, {"%", "Modulus"}, {"^", "Raise to power"}
    }) do
        add(v[1], v[2] .. " Operator", function(state)
            local a, b = state:popStack(2)

            local r = {a = a, b = b}
            function r:transpile()
                return self.a.variable .. " " .. v[1] .. " " .. self.b.variable
            end

            state:pushStack(r)
        end)
    end

    -- Comparison

    for _, v in pairs({
        {">", "Greater than"}, {"<", "Less than"},
        {"≥", "Greater than or equal to", ">="},
        {"≤", "Less than or equal to", "<="}
    }) do
        add(v[1], v[2] .. " Comparison", function(state)
            local a, b = state:popStack(2)

            local r = {a = a, b = b}
            function r:transpile()
                return self.a.variable .. " " .. (v[3] or v[1]) .. " " ..
                           self.b.variable
            end

            state:pushStack(r)
        end)
    end

    -- Unary

    add("∅", "Pop", function(state) state:popStack(1) end)

    add("⏟", "Wrap a in table", function(state)
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile() return "{" .. self.a.variable .. "}" end

        state:pushStack(r)
    end)

    add("¹", "Push first element of a", function(state)
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile() return self.a.variable .. "[1]" end

        state:pushStack(r)
    end)

    add("ⁿ", "Push last element of a", function(state)
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile()
            return self.a.variable .. "[#" .. self.a.variable .. "]"
        end

        state:pushStack(r)
    end)

    add("⤼", "Decrement a", function(state)
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile() return self.a.variable .. " - " .. "1" end

        state:pushStack(r)
    end)

    add("⤽", "Increment a", function(state)
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile() return self.a.variable .. " + " .. "1" end

        state:pushStack(r)
    end)

    -- statements with blocks
    add("⇄", "Map each element in a", function(state)
        local a = state.stack[1]

        local childState, start = state:block()
        childState.stack = {{variable = "element"}}

        local r = {statement = true, a = a, block = start()}
        function r:transpile()
            local indent = rep("\t", state.depth)
            local mapStatement = ""
            if childState.stack[1] then
                mapStatement = self.a.variable .. "[index] = " ..
                                   childState.stack[1].variable
            end
            return
                "for index, element in pairs(" .. self.a.variable .. ") do\n" ..
                    self.block .. "\n\t" .. indent .. mapStatement .. "\n" ..
                    indent .. "end\n"
        end

        state:pushStack(r)
    end)
end

local gmatch = string.gmatch
interpret = function(state)
    local stack = state.stack
    local buffer = {}

    state:onPushStack(function(object)
        local prefix = ""
        if not object.statement then
            prefix = "local " .. object.variable .. " = "
        end

        insert(buffer, prefix .. object:transpile())
    end)

    state.iter = state.iter or gmatch(state.input, unicode)
    local iter = state.iter

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

    local tk = iter()
    assert(tk, "file is empty")
    repeat
        state.currentMark = tk

        local command = commands[tk]
        assert(command, "unexpected token `" .. tk .. "`")
        command.f(state)

        tk = iter()
    until not tk or tk == ")"

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
