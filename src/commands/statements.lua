local add = require"commands".add

-- Nullary

add("⭝", "Pop stack", function(state) state:popStack(1) end)

local function reverse(tbl)
    local len = #tbl
    local ret = {}

    for i = len, 1, -1 do ret[len - i + 1] = tbl[i] end

    return ret
end

add("↺", "Reverse stack",
    function(state) state.stack = reverse(state.stack) end)

-- Unary

add("↑", "Print a", function(state)
    local a = state:popStack(1)
    state.push("print(" .. a.variable .. ")")
end)

add("⇑", "Verbose print a", function(state)
    state:import("debug")

    local a = state:popStack(1)
    state.push("_debug(" .. a.variable .. ")")
end)

-- Statements with subblocks

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

    state.push(interpolate("if %2 then\n%3%4\n%1end", indent, a.variable, block,
                           elseClause))
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

    state.push(interpolate("for index, element in pairs(%3)\n%2\n\t%1%4\n%1end",
                           rep("\t", state.depth), block, a.variable,
                           mapStatement))
end)
