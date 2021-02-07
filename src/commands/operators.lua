local add = require"commands".add

-- Unary

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

-- Binary

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

for i, v in pairs({
    {"⤼", "Decrement a", "a - 1"}, {"⤽", "Increment a", "a + 1"},
    {"½", "Half a", "a / 2"}, {"⅟", "Push inverse of a", "1 / a"},
    {"↞", "Double a", "a * 2"}, {"⑽", "Multiply a by ten", "a * 10"},
    {"°", "Push a to the tenth power", "a ^ 10"}
}) do
    add(v[1], v[2], function(state)
        a = state:popStack(1)

        local r = {a = a}
        function r:transpile()
            return v[3]:gsub("element", self.a.variable)
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
