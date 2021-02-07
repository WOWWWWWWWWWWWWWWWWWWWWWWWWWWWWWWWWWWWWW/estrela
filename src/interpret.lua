local interpret

local unicode = "[%z\1-\127\194-\244][\128-\191]*"

local commands = {}
local function add(symbol, description, f, number)
    assert(#commands < 256, "no more commands allowed") -- TODO: Multi-symbol commands
    if type(symbol) ~= "table" then symbol = {symbol} end

    for _, alias in pairs(symbol) do
        commands[alias] = {description = description, f = f, number = number}
    end
end

local insert = table.insert
local concat = table.concat
local gsub = string.gsub
local sub = string.sub
local rep = string.rep
local lower = string.lower

local interpolate = function(template, ...)
    local args = {...}
    local result = gsub(template, "%%(%d+)", function(n)
        local r = args[tonumber(n)]
        assert(r, n .. " in string interpolation does not exist")
        return r
    end)
    return result
end

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
                if head.hexadecimal then
                    head.v = head.v .. i
                else
                    head.v = (head.v * 10) + i
                end
            else
                local r = {v = i}
                function r:transpile() return self.v end
                state.currentNumber = r
            end
        end, true)
    end

    -- Hexadecimal modifiers
    for _, v in pairs({"A", "B", "C", "D", "E", "F"}) do
        add({v, lower(v)}, "Hexadecimal literal " .. v, function(state)
            local head = state.currentNumber
            if head then
                if head.hexadecimal then
                    head.v = head.v .. v
                else
                    head.v = tostring(head.v) .. v
                    function head:transpile()
                        return "0x" .. self.v
                    end
                end
            else
                local r = {v = v, hexadecimal = true}
                function r:transpile() return "0x" .. self.v end
                state.currentNumber = r
            end
        end, true)
    end

    -- String literals
    local function pushstring(state, v)
        local r = {table = true, v = v}

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

    add({'ˎ', '˴'}, "Character literal",
        function(state) pushstring(state, state.next()) end)

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
        state:import("concat")
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
        {"≤", "Less than or equal to", "<="}, {"≟", "Equal to", "=="},
        {"≠", "Not equal to", "~="}
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

        for i = len, 1, -1 do ret[len - i + 1] = tbl[i] end

        return ret
    end

    add("↺", "Reverse stack",
        function(state) state.stack = reverse(state.stack) end)

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

        local r = {table = true, a = a}
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

    add("?", "Push random element of a", function(state)
        stat:import("random")
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile()
            return self.a.variable .. "[random(1, #" .. self.a.variable .. ")]"
        end

        state:pushStack(r)
    end)

    add("⁇", "Fisher-Yates shuffle a", function(state)
        stat:import("random")

        local a = state.stack[1]
        stat.push(
            "%1for i = #%2, 2, -1 do\n\t%1local j = random(i)\n\t%1%2[i], %2[j] = %2[j], %2[i]\n%1end",
            rep("\t", state.depth), a.variable)
    end)

    add("↣", "Pop last element of a", function(state)
        state:import("remove")
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile() return "remove(" .. self.a.variable .. ")" end

        state:pushStack(r)
    end)

    add("↦", "Pop first element of a", function(state)
        state:import("remove")
        local a = state:popStack(1)

        local r = {a = a}
        function r:transpile()
            return "remove(" .. self.a.variable .. ", 1)"
        end

        state:pushStack(r)
    end)

    local format
    local function easyMap(depth, var, rhs)
        return interpolate(
                   "for index, element in pairs(%2)\n\t%1%2[index] = %3\n%1end",
                   rep("\t", depth), var, rhs)
    end

    for i, v in pairs({
        {"⤼", "Decrement a", "element - 1"},
        {"⤽", "Increment a", "element + 1"}, {"½", "Half a", "element / 2"},
        {"⅟", "Push inverse of a", "1 / element"},
        {"↞", "Double a", "element * 2"},
        {"⑽", "Multiply a by ten", "element * 10"},
        {"°", "Push a to the tenth power", "element ^ 10"}
    }) do
        add(v[1], v[2], function(state)
            local a = state.stack[1]
            if a.table then
                state.push(easyMap(state.depth, a.variable, v[3]))
            else
                a = state:popStack(1)

                local r = {a = a}
                function r:transpile()
                    return gsub(v[3], "element", self.a.variable)
                end

                state:pushStack(r)
            end
        end)
    end

    -- statements with blocks
    add("(", "If statement: `CONDITION(CODE|ELSE)", function(state)
        local a = state:popStack(1)
        local indent = rep("\t", state.depth)

        local childState, start = state:block()
        childState.terminator = "|"
        local block = start()

        local elseClause = ""
        if childState.currentMark == "|" then
            local _, start = state:block()
            elseCode = start()
            elseClause = interpolate("\n%1else\n%2", indent, elseCode)
        end

        state.push(interpolate("if %2 then\n%3%4\n%1end", indent, a.variable,
                               block, elseClause))
    end)

    add("↻", "Repeat statement: `↻CODE & CONDITION)", function(state)
        local indent = rep("\t", state.depth)

        local childState, start = state:block()
        local block = start()

        assert(#childState.stack ~= 0,
               "Repeat statement body should not have an empty stack")

        local condition = childState.stack[1].variable
        state.push(interpolate("repeat\n%2\n%1until %3", indent, block,
                               condition.variable, block, elseClause))
    end)

    add("⇄", "Map each element in a: `⇄CODE)`", function(state)
        local a = state.stack[1]

        local childState, start = state:block()
        childState.stack = {{variable = "element"}}
        local block = start()

        local mapStatement = childState.stack[1] and
                                 (a.variable .. "[index] = " ..
                                     childState.stack[1].variable) or ""

        state.push(interpolate(
                       "for index, element in pairs(%3)\n%2\n\t%1%4\n%1end",
                       rep("\t", state.depth), block, a.variable, mapStatement))
    end)
end

local count = 1 -- Include | in if statement
for _ in pairs(commands) do count = count + 1 end
print("Interpreter loaded with " .. count .. " commands")

local gmatch = string.gmatch
interpret = function(state)
    local stack = state.stack
    local terminator = state.terminator

    local buffer = {}

    state:onPushStack(function(object)
        insert(buffer,
               "local " .. object.variable .. " = " .. object:transpile())
    end)

    state.iter = state.iter or gmatch(state.input, unicode)
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
        assert(command, "unexpected token `" .. tk .. "`")
        command.f(state)

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
