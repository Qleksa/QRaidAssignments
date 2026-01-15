---@class QRA
local QRA = QRA

--- Count table entries
---@param tbl table
---@return number
function QRA.TableCount(tbl)
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
function QRA.TableMerge(dest, src)
    for k, v in pairs(src) do
        dest[k] = v
    end
    return dest
end
