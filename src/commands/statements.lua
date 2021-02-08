local add = require"commands".add

-- Nullary

add("⭝", "Pop a", function(state) state:popStack(1) end)
add("⇢", "Pop a, b and push a", function(state)
    local a, b = state:popStack(2)
    a:unpop()
end)

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

local ifTemplate = --
[[if ${condition} then
${code}${elseClause}
end]]

add("(", "If statement: `CONDITION(CODE|ELSE)", function(state)
    local a = state:popStack(1)

    local childState, start = state:block()
    childState.terminator = "|"
    local block = start()

    local elseClause = ""
    if childState.currentMark == "|" then
        local _, start = state:block()
        elseCode = start()
        elseClause = interpolate("\n%1else\n%2", indent, elseCode)
    end

    state.push(i(ifTemplate, state, {
        condition = a.variable,
        code = block,
        elseClause = elseClause
    }))
end)

local repeatTemplate = --
[[repeat
${code}
until ${condition}]]

add("↻", "Repeat statement: `↻CODE & CONDITION)", function(state)
    local childState, start = state:block()
    local block = start()

    assert(#childState.stack ~= 0,
           "Repeat statement body should not have an empty stack")

    local condition = childState.stack[1].variable
    state.push(i(repeatTemplate, state, {code = block, condition = condition}))
end)

local mapTemplate = --
[[for index, element in pairs(${aVar}) do
${code}
    ${mapStatement}
end]]

add("⇄", "Map each element in a: (stack: index, element) `⇄CODE)`",
    function(state)
    local a = state.stack[1]

    local childState, start = state:block()
    childState.stack = {{variable = "index"}, {variable = "element"}}
    local block = start()

    local mapStatement = childState.stack[1] and
                             (a.variable .. "[index] = " ..
                                 childState.stack[1].variable) or ""

    state.push(i(mapTemplate, state,
                 {aVar = a.variable, code = block, mapStatement = mapStatement}))
end)

local forEachTemplate = --
[[for index, element in pairs(${aVar}) do
${code}
end]]

add("→", "For each element in a: (stack: index, element) `→CODE)`",
    function(state)
    local a = state.stack[1]

    local childState, start = state:block()
    childState.stack = {{variable = "index"}, {variable = "element"}}
    local block = start()

    state.push(i(forEachTemplate, state, {aVar = a.variable, code = block}))
end)
