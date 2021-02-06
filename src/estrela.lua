package.path = package.path .. ";./src/?.lua"
local args = {...}

assert(#args >= 2, "2 or more args required")

local mode = args[1]
local file = args[2]

local io = require "io"
local open = io.open

local interpret = require "interpret"
local State = require "state"

local function read(fn)
    local i = open(fn, "rb")
    assert(i, "file doesn't exist in current directory")

    local r = i:read("*a")
    i:close()
    return r
end

local function transpile(fn, input)
    if not input then input = read(fn) end

    local stem = fn:match("(.+)%..+")
    local o = open(stem .. ".lua", "w")
    o:write(interpret(State:new(input)))
    o:close()
end

local clock = os.clock
function sleep(n) -- seconds
    local t0 = clock()
    while clock() - t0 <= n do end
end

if mode == "transpile" then
    transpile(file)
elseif mode == "watch" then
    local storage
    while true do
        sleep(2)
        local input = read(file)
        if input ~= storage then
            local success, err = pcall(function()
                transpile(file, input)
            end)
            if not success then print("watch error: " .. err) end
            storage = input
        end
    end
else
    error("Unrecognized mode `" .. mode .. "`")
end
