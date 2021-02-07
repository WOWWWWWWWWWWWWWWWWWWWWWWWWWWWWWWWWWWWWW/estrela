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
            local head = state.currentNumber
            if head then
                head.v = (head.v * 10) + i
            else
                local r = {v = i, concatableNumber = true}
                function r:transpile() return self.v end
                state.currentNumber = r
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

        local b = state:popStack(1)
        local a = state.stack[0]

        state.push("insert(" .. self.a.variable .. ", 1, " .. self.b.variable ..
                       ")")
    end)

    add("⊶", "Append b to a", function(state)
        state:import("insert")

        local b = state:popStack(1)
        local a = state.stack[0]

        state.push("insert(" .. self.a.variable .. ", " .. self.b.variable ..
                       ")")
    end)

    add("⇥", "Push joined table a", function(state)
        import("concat")
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile() return "concat(" .. self.a.variable .. ")" end

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

    add("⭝", "Pop stack", function(state) state:popStack(1) end)

    local function reverse(tbl)
        local len = #tbl
        local ret = {}

        for i = len, 1, -1 do
            ret[ len - i + 1 ] = tbl[ i ]
        end

        return ret
    end

    add("↺", "Reverse stack", function(state)
        state.stack = reverse(state.stack)
    end)

    add(":", "Duplicate a", function(state)
        local a = state:popStack(1)

        for i = 1, 2 do
            local r = {a = a}
            function r:transpile() return self.a.variable end
            state:pushStack(r)
        end
    end)

    add("⋮", "Triplicate a", function(state)
        local a = state:popStack(1)

        for i = 1, 3 do
            local r = {a = a}
            function r:transpile() return self.a.variable end
            state:pushStack(r)
        end
    end)

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

    add("ⁿ", "Pop last element of a", function(state)
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
        function r:transpile() return self.a.variable .. " - 1" end

        state:pushStack(r)
    end)

    add("⤽", "Increment a", function(state)
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile() return self.a.variable .. " + 1" end

        state:pushStack(r)
    end)

    add("½", "Half a", function(state)
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile() return self.a.variable .. " / 2" end

        state:pushStack(r)
    end)

    add("⅟", "Push inverse of a", function(state)
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile() return "1 / " .. self.a.variable end

        state:pushStack(r)
    end)

    add("↞", "Double a", function(state)
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile() return self.a.variable .. " * 2" end

        state:pushStack(r)
    end)

    add("⑽", "Multiply a by ten", function(state)
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile() return self.a.variable .. " * 10" end

        state:pushStack(r)
    end)

    add("°", "Push a to the tenth power", function(state)
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile() return self.a.variable .. " ^ 10" end

        state:pushStack(r)
    end)

    -- statements with blocks
    add("⇄", "Map each element in a", function(state)
        local a = state.stack[1]

        local childState, start = state:block()
        childState.stack = {{variable = "element"}}
        local block = start()

        local indent = rep("\t", state.depth)
        local mapStatement =
            childState.stack[1] and a.variable .. "[index] = " ..
                childState.stack[1].variable or ""

        state.push("for index, element in pairs(" .. a.variable .. ") do\n" ..
                       block .. "\n\t" .. indent .. mapStatement .. "\n" ..
                       indent .. "end\n")
    end)
end

local gmatch = string.gmatch
local match = string.match
interpret = function(state)
    local stack = state.stack
    local buffer = {}

    state:onPushStack(function(object)
        insert(buffer,
               "local " .. object.variable .. " = " .. object:transpile())
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

    function state.push(str) insert(buffer, str) end

    local tk = iter()
    assert(tk, "file is empty")
    repeat
        state.currentMark = tk

        local command = commands[tk]
        assert(command, "unexpected token `" .. tk .. "`")
        command.f(state)

        tk = iter()

        -- ugly hack
        if state.currentNumber and (not tk or not match(tk, "%d+")) then
            state:pushStack(state.currentNumber)
            state.currentNumber = nil
        end
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
