local add = require"commands".add

-- Unary

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

add("↣", "Pop and push last element of a", function(state)
    state:import("table")
    local a = state:popStack(1)

    local r = {a = a}
    function r:transpile() return "remove(" .. self.a.variable .. ")" end

    state:pushStack(r)
end)

add("↦", "Pop and push first element of a", function(state)
    state:import("table")
    local a = state:popStack(1)

    local r = {a = a}
    function r:transpile() return "remove(" .. self.a.variable .. ", 1)" end

    state:pushStack(r)
end)

-- //

add("⇥", "Join a", function(state)
    state:import("table")
    local a = state:popStack(1)

    local r = {a = a}
    function r:transpile() return "concat(" .. self.a.variable .. ")" end

    state:pushStack(r)
end)

local shuffleArrayTemplate = --
[[for i = #${aVar}, 2, -1 do
    local j = random(i)
    ${aVar}[i], ${aVar}[j] = ${aVar}[j], ${aVar}[i]
end]]

add("⁇", "Fisher-Yates shuffle a", function(state)
    state:import("random")

    local a = state.stack[1]
    state.push(i(shuffleArrayTemplate, state, {aVar = a.variable}))
end)

local numericByteArrayTemplate = --
[[local _map = {}
for e in gmatch(${aForVar}, ".") do
    insert(_map, byte(e))
end
${aVar} = _map]]

add("⇔", "Convert a to numeric byte array", function(state)
    state:import("string")
    state:import("table")

    local a = state.stack[1]
    state.push(i(numericByteArrayTemplate, state, {
        aVar = a.variable,
        aForVar = a.table and "concat(" .. a.variable .. ")" or a.variable
    }))
end)

local charByteArrayTemplate = --
[[local _map = {}
for e in gmatch(${aForVar}, ".") do
    insert(_map, e)
end
${aVar} = _map]]

add("⇎", "Convert a to char byte array", function(state)
    state:import("string")
    state:import("table")

    local a = state.stack[1]
    state.push(i(charByteArrayTemplate, state, {
        aVar = a.variable,
        aForVar = a.table and "concat(" .. a.variable .. ")" or a.variable
    }))
end)

local codepointArrayTemplate = --
[[local _map = {}
for e in umatch(${aForVar}, ".") do
    insert(_map, unicode(e))
end
${aVar} = _map]]

add("⇿", "Convert a to codepoint array", function(state)
    state:import("utf8")
    state:import("table")

    local a = state.stack[1]
    state.push(i(codepointArrayTemplate, state, {
        aVar = a.variable,
        aForVar = a.table and "concat(" .. a.variable .. ")" or a.variable
    }))
end)

-- Binary

add("⊷", "Prepend b to a", function(state)
    state:import("table")

    local b = state:popStack(1)
    local a = state.stack[0]

    state.push("insert(" .. self.a.variable .. ", 1, " .. self.b.variable .. ")")
end)

add("⊶", "Append b to a", function(state)
    state:import("table")

    local b = state:popStack(1)
    local a = state.stack[0]

    state.push("insert(" .. self.a.variable .. ", " .. self.b.variable .. ")")
end)
