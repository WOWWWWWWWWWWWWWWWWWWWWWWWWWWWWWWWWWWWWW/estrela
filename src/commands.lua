local commands = {}
local count = 1 -- Include | in if statement
local function add(symbol, description, f, number)
    count = count + 1
    assert(count < 256, "no more commands allowed") -- TODO: Multi-symbol commands
    if type(symbol) ~= "table" then symbol = {symbol} end

    for _, alias in pairs(symbol) do
        commands[alias] = {description = description, f = f, number = number}
    end
end

return {commands = commands, add = add, count = function() return count end}
