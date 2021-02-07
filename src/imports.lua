return {
    debug = 'local _debug = require "src.imports.debug"',

    utf8 = [[
        local utf8 = require "src.imports.utf8"
        local unicode = utf8.unicode
        local umatch = utf8.gmatch
    ]],

    table = [[
        local concat = table.concat
        local insert = table.insert
        local remove = table.remove
    ]],

    random = "math.randomseed(os.time());local random = math.random",

    string = [[
        local gmatch = string.gmatch
        local byte = string.byte
    ]]
}
