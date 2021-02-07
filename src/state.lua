local insert = table.insert
local remove = table.remove
local State = {}

function State:new(state)
    state.stack = state.stack or {}
    state.imports = state.imports or {}

    state.unsafe = state.unsafe or true
    state.safe = not state.unsafe

    state.depth = state.parent and (state.parent.depth + 1) or 0
    state.events = {onPushStack = {}}

    setmetatable(state, self)
    self.__index = self

    return state
end

function State:onPushStack(f) insert(self.events.onPushStack, f) end

function State:pushStack(object)
    if self.safe then
        assert(object.type, "Safemode: No `type` on object")
        assert(object.transpile, "Safemode: No `transpile` on object")
    end

    object.variable = "_" .. (self.depth ~= 0 and self.depth or "") .. "_" ..
                          (#self.stack + 1)

    for _, event in pairs(self.events.onPushStack) do event(object) end
    insert(self.stack, 1, object)
end

function State:popStack(count, _if)
    local r = {}
    for i = 1, count do
        insert(r, remove(self.stack, 1) or
                   {
                type = "unknown",
                variable = "nil --[[ Popped empty stack. ]]"
            })
    end
    return unpack(r)
end

local interpret = require "interpret"
local imports = require "imports"

local rep = string.rep
function State:interpret()
    local depth = self.depth
    local code = interpret(self)
    if depth == 0 then
        local importCode = "--// Imports\n\n"

        for name in pairs(self.imports) do
            local import = imports[name]
            assert(self.unsafe or import,
                   "Import `" .. name .. "` does not exist.")
            importCode = importCode .. "--/ " .. name .. "\n" ..
                             import:gsub("    ", "") .. "\n\n"
        end

        return importCode .. "--// Main\n\n" .. code
    else
        return rep("\t", depth) .. "--// λ " .. depth .. "\n" .. code
    end
end

local sub = string.sub
function State:block()
    local childState = State:new{parent = self, iter = self.iter}
    return childState, function()
        local code = childState:interpret()
        for import in pairs(childState.imports) do self[import] = true end
        return code
    end
end

function State:import(name) self.imports[name] = true end

return State
