---@class QRA
local QRA = select(2, ...)

---@class Table
QRA.Table = {}

--- Count table entries
---@param tbl table
---@return number
function QRA.Table.Count(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

--- Merge two tables (shallow)
---@param dest table
---@param src table
---@return table
function QRA.Table.Merge(dest, src)
    for k, v in pairs(src) do
        dest[k] = v
    end
    return dest
end
