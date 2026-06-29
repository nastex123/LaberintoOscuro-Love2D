-- Minimal JSON library (rxi/json.lua) – public domain
local json = {}

local encode
local escape_char_map = { ["\\"] = "\\\\", ["\""] = "\\\"", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local function escape_char(c) return escape_char_map[c] or string.format("\\u%04x", c:byte()) end
function json.encode(val)
    if type(val) == "nil" then return "null" end
    if type(val) == "boolean" then return tostring(val) end
    if type(val) == "number" then return tostring(val) end
    if type(val) == "string" then
        return '"'..val:gsub('[%z\"%c]', escape_char)..'"'
    end
    if type(val) == "table" then
        local isArray = (#val > 0)
        local result = {}
        if isArray then
            for i=1,#val do table.insert(result, json.encode(val[i])) end
            return '['..table.concat(result,',')..']'
        else
            for k,v in pairs(val) do
                if type(k) ~= "string" then error('JSON object keys must be strings') end
                table.insert(result, json.encode(k)..':'..json.encode(v))
            end
            return '{'..table.concat(result,',')..'}'
        end
    end
    error('unsupported type: '..type(val))
end

local function decode_error(str, idx, msg) error(string.format('JSON decode error at %d: %s (%s)', idx, msg, str:sub(idx, idx+10))) end

function json.decode(str)
    local pos = 1
    local function skipWhitespace()
        pos = string.find(str, '[^%s]', pos) or #str+1
    end
    local function parseValue()
        skipWhitespace()
        local char = str:sub(pos,pos)
        if char == '{' then return parseObject() end
        if char == '[' then return parseArray() end
        if char == '"' then return parseString() end
        if char:match('[-%d]') then return parseNumber() end
        if str:sub(pos, pos+3) == 'true' then pos = pos+4; return true end
        if str:sub(pos, pos+4) == 'false' then pos = pos+5; return false end
        if str:sub(pos, pos+3) == 'null' then pos = pos+4; return nil end
        decode_error(str, pos, 'invalid value')
    end
    local function parseObject()
        pos = pos + 1
        local obj = {}
        skipWhitespace()
        if str:sub(pos,pos) == '}' then pos = pos + 1; return obj end
        while true do
            skipWhitespace()
            if str:sub(pos,pos) ~= '"' then decode_error(str, pos, 'expected string key') end
            local key = parseString()
            skipWhitespace()
            if str:sub(pos,pos) ~= ':' then decode_error(str, pos, 'expected colon') end
            pos = pos + 1
            obj[key] = parseValue()
            skipWhitespace()
            local delim = str:sub(pos,pos)
            if delim == '}' then pos = pos + 1; break end
            if delim ~= ',' then decode_error(str, pos, 'expected comma or }') end
            pos = pos + 1
        end
        return obj
    end
    local function parseArray()
        pos = pos + 1
        local arr = {}
        skipWhitespace()
        if str:sub(pos,pos) == ']' then pos = pos + 1; return arr end
        while true do
            table.insert(arr, parseValue())
            skipWhitespace()
            local delim = str:sub(pos,pos)
            if delim == ']' then pos = pos + 1; break end
            if delim ~= ',' then decode_error(str, pos, 'expected comma or ]') end
            pos = pos + 1
        end
        return arr
    end
    local function parseString()
        pos = pos + 1
        local start = pos
        local result = ''
        while true do
            local ch = str:sub(pos,pos)
            if ch == '"' then break end
            if ch == '\\' then
                result = result .. str:sub(start, pos-1)
                pos = pos + 1
                local esc = str:sub(pos,pos)
                if esc == '"' or esc == '\\' or esc == '/' then result = result .. esc
                elseif esc == 'b' then result = result .. '\b'
                elseif esc == 'f' then result = result .. '\f'
                elseif esc == 'n' then result = result .. '\n'
                elseif esc == 'r' then result = result .. '\r'
                elseif esc == 't' then result = result .. '\t'
                elseif esc == 'u' then
                    local hex = str:sub(pos+1, pos+4)
                    if not hex:match('%x%x%x%x') then decode_error(str, pos, 'invalid unicode escape') end
                    result = result .. utf8.char(tonumber(hex,16))
                    pos = pos + 4
                else decode_error(str, pos, 'invalid escape') end
                pos = pos + 1
                start = pos
            else
                pos = pos + 1
            end
        end
        result = result .. str:sub(start, pos-1)
        pos = pos + 1
        return result
    end
    local function parseNumber()
        local start = pos
        local numStr = str:match('[-+%d.eE]+', pos)
        if not numStr then decode_error(str, pos, 'invalid number') end
        pos = pos + #numStr
        local num = tonumber(numStr)
        if not num then decode_error(str, start, 'invalid number') end
        return num
    end
    local result = parseValue()
    skipWhitespace()
    if pos <= #str then decode_error(str, pos, 'trailing garbage') end
    return result
end

return json
