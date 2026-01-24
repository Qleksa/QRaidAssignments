---@class QRA
local QRA = select(2, ...)

---@class QRA_BossMods | QRA_Module
QRA.BossMods = QRA.BossMods or {}

---@class QRA_DBM
---@field private registeredEvents table<string, boolean>
local dbm = {
    registeredEvents = {},

    EventCallback = function(self, event, ...)
        if event == "DBM_SetStage" or event == "DBM_Pull" or event == "DBM_Wipe" or event == "DBM_Kill" then
            local stage = DBM:GetStage()
            QRA.Debug("BossMods: DBM stage set to", stage)
            QRA.Encounter.SetPhase(stage)

            if event == "DBM_Wipe" then
                QRA.Encounter.End(false)
            elseif event == "DBM_Kill" then
                QRA.Encounter.End(true)
            end
        end
    end,

    RegisterCallback = function(self, event, callback)
        if self.registeredEvents[event] then
            return
        end
        if DBM then
            DBM:RegisterCallback(event, function(...)
                if callback then
                    callback(...)
                else
                    self:EventCallback(event, ...)
                end
             end)
            self.registeredEvents[event] = true
            QRA.Debug("BossMods: DBM callback registered for event", event)
        end
    end,

    --- Register stage change callbacks
    RegisterStage = function(self, callback)
        QRA.Debug("BossMods: Registering DBM stage callbacks")
        self:RegisterCallback("DBM_SetStage", callback)
    end,
}

function QRA.BossMods:SetupDBM()
    if not DBM then
        QRA.Print("DBM not detected.")
        return nil
    end
    QRA.Print("DBM detected.")
    return dbm
end
