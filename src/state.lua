local insert = table.insert
local remove = table.remove
local State = {}

function State:new(input, state)
    state = state or {}

    state.input = input
    state.stack = state.stack or {}

    state.unsafe = state.unsafe or true
    state.safe = not state.unsafe

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

    object.variable = "__" .. (#self.stack + 1)

    for _, event in pairs(self.events.onPushStack) do event(object) end
    insert(self.stack, 1, object)
end

function State:popStack(count, _if)
    if not _if or _if(self.stack) then
        local r = {}
        for i = 1, count do insert(r, remove(self.stack, 1)) end
        return unpack(r)
    end
end

return State
