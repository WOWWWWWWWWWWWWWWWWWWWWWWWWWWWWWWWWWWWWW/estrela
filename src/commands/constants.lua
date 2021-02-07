local add = require"commands".add

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
                function head:transpile() return "0x" .. self.v end
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
        for from, to in pairs(replace) do v = v:gsub(from, to) end

        v = v:gsub(unicode, function(c) return '"' .. c .. '", ' end)
        v = v:sub(1, -3)
        return '{' .. v .. '}'
    end

    state:pushStack(r)
end

add({'`', '`'}, "String literal",
    function(state) pushstring(state, state.lookFor(state.currentMark)) end)

add({'ˎ', '˴'}, "Character literal",
    function(state) pushstring(state, state.next()) end)
