---@class QRA
local QRA = select(2, ...)

---@class Logger
QRA.Logger = {}
local Logger = QRA.Logger ---@class Logger

---@class Log
---@field timestamp string
---@field message string

---@type string[]
local logs = {}

function QRA.Logger.Log(message)
    table.insert(logs, date() .. ': ' .. message)
end

function QRA.Logger.SaveLogs()
    local lg = {}

    -- table.insert(lg, '--- New Session ---')
    table.insert(lg, table.concat(logs, '\n'))
    -- table.insert(lg, '--- End of Session ---\n')

    QRA.DB.logs = QRA.Serialize(lg)
end

function QRA.Logger.LoadLogs()
    if QRA.DB.logs then
        local deserialized = QRA.Deserialize(QRA.DB.logs)
        if deserialized then
            logs = deserialized
        end
    end
end

function QRA.Logger.ClearLogs()
    QRA.DB.logs = nil
    logs = {}
end

function QRA.Logger.GetLogs()
    return logs
end
