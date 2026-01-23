---@class QRA
local QRA = select(2, ...)

local function dump(o, indent)
    indent = indent or 0
    local indentStr = string.rep('  ', indent)
    local nextIndentStr = string.rep('  ', indent + 1)

    if type(o) == 'table' then
        local s = '{\n'
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. nextIndentStr .. '[' .. k .. '] = ' .. dump(v, indent + 1) .. ',\n'
        end
        return s .. indentStr .. '}'
    else
        return tostring(o)
    end
end

function QRA.Debug(...)
    if QRA.Settings.debug then
        local args = {...}
        local output = "|cFFFFA500[QRA Debug]:|r "

        for _, arg in pairs(args) do
            if type(arg) == 'table' then
                print(output)
                print(dump(arg))
                output = "|cFFFFA500[QRA Debug]:|r "
            else
                output = output .. " " .. tostring(arg)
            end
        end

        if output ~= "|cFFFFA500[QRA Debug]:|r " then
            print(output)
        end
    end
end
