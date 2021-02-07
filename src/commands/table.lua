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
    function r:transpile()
        return "remove(" .. self.a.variable .. ", 1)"
    end

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

add("⁇", "Fisher-Yates shuffle a", function(state)
    stat:import("random")

    local a = state.stack[1]
    stat.push(
        "%1for i = #%2, 2, -1 do\n\t%1local j = random(i)\n\t%1%2[i], %2[j] = %2[j], %2[i]\n%1end",
        rep("\t", state.depth), a.variable)
end)

add("⇔", "Convert a to numeric byte array", function(state)
    state:import("string")
    state:import("table")

    local a = state.stack[1]
    state.push(interpolate(
                   'local _map = {}\n%1for e in gmatch(%3, ".") do\n\t%1insert(_map, byte(e))\n%1end\n%1%2 = _map',
                   rep("\t", state.depth), a.variable,
                   a.table and "concat(" .. a.variable .. ")" or a.variable))
end)

add("⇎", "Convert a to char byte array", function(state)
    state:import("string")
    state:import("table")

    local a = state.stack[1]
    state.push(interpolate(
                   'local _map = {}\n%1for e in gmatch(%3, ".") do\n\t%1insert(_map, e)\n%1end\n%1%2 = _map',
                   rep("\t", state.depth), a.variable,
                   a.table and "concat(" .. a.variable .. ")" or a.variable))
end)

add("⇿", "Convert a to codepoint array", function(state)
    state:import("utf8")
    state:import("table")

    local a = state.stack[1]
    state.push(interpolate(
                   'local _map = {}\n%1for e in umatch(%3, ".") do\n\t%1insert(_map, unicode(e))\n%1end\n%1%2 = _map',
                   rep("\t", state.depth), a.variable,
                   a.table and "concat(" .. a.variable .. ")" or a.variable))
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
