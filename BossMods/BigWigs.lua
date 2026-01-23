---@class QRA
local QRA = QRA

QRA.BossMods = QRA.BossMods or {}

---@class QRA_BigWigs
local bigWigs = {
    registeredEvents = {},
    currentStage = 0,

    EventCallback = function(self, event, ...)
        QRA.Debug("BossMods: BigWigs event received:", event)

        if event == "BigWigs_SetStage" then
            local _, _, stage = ...
            self.currentStage = stage
            QRA.Debug("BossMods: BigWigs stage set to", stage)
            QRA.Encounter.SetPhase(stage)
        elseif event == "BigWigs_OnBossWipe" then
            self.currentStage = 0
            QRA.Debug("BossMods: BigWigs stage reset to 0")
            QRA.Encounter.End(false)
        elseif event == "BigWigs_OnBossWin" then
            self.currentStage = 0
            QRA.Debug("BossMods: BigWigs stage reset to 0")
            QRA.Encounter.End(true)
        elseif event == "BigWigs_Timer"
            or event == "BigWigs_TargetTimer"
            or event == "BigWigs_CastTimer"
            or event == "BigWigs_StartBreak"
            or event == "BigWigs_StartPull"
        then
            local key, duration, _, text, count, icon, isCooldown, isBarEnabled, timerType
            if event == "BigWigs_Timer" then
                _, _, key, duration, _, text, count, icon, isCooldown, isBarEnabled = ...
                timerType = "timer"
            elseif event == "BigWigs_TargetTimer" or event == "BigWigs_CastTimer" then
                _, _, key, duration, _, text, count, icon, _, isBarEnabled = ...
                isCooldown = false
                timerType = "cast"
            elseif event == "BigWigs_StartBreak" then
                _, _, duration, _, _, _, text, icon = ...
                text = text
                key = -1
                count = 0
                icon = icon
                isCooldown = false
                isBarEnabled = true
                timerType = "break"
            elseif event == "BigWigs_StartPull" then
                _, _, duration, _, text, icon = ...
                text = text
                key = -2
                count = 0
                icon = 136116
                isCooldown = false
                isBarEnabled = true
                timerType = "pull"
            end

            QRA.Debug("BossMods: BigWigs Timer - Type:", timerType, " SpellID:", key, " Duration:", duration, " Text:", text, " Count:", count, " Icon:", icon, " IsCooldown:", isCooldown, " IsBarEnabled:", isBarEnabled)
        end
    end,

    RegisterCallback = function(self, event)
        if self.registeredEvents[event] then return end

        if BigWigsLoader then
            BigWigsLoader.RegisterMessage(QRA, event, function(...) self:EventCallback(event, ...) end)
            self.registeredEvents[event] = true
            if event == "BigWigs_SetStage" then
                if BigWigs and BigsWigs.IterateBossModules then
                    local stage = 0
                    for _, module in BigWigs:IterateBossModules() do
                        if module:IsEngaged() then
                            stage = math.max(stage, module:GetStage() or 1)
                        end
                    end
                    self.currentStage = stage
                end
            end
        end
    end,

    GetStage = function(self)
        return self.currentStage
    end,

    RegisterTimer = function(self)
        QRA.Debug("BossMods: Registering BigWigs Timer callbacks")
        self:RegisterCallback("BigWigs_Timer")
        self:RegisterCallback("BigWigs_TargetTimer")
        self:RegisterCallback("BigWigs_StartBreak")
        self:RegisterCallback("BigWigs_CastTimer")
        self:RegisterCallback("BigWigs_StopBar")
        self:RegisterCallback("BigWigs_StopBars")
        self:RegisterCallback("BigWigs_OnBossDisable")
        self:RegisterCallback("BigWigs_PauseBar")
        self:RegisterCallback("BigWigs_ResumeBar")
        self:RegisterCallback("BigWigs_StartPull")
    end,

    RegisterStage = function(self)
        QRA.Debug("BossMods: Registering BigWigs Stage callbacks")
        self:RegisterCallback("BigWigs_SetStage")
        self:RegisterCallback("BigWigs_OnBossWipe")
        self:RegisterCallback("BigWigs_OnBossWin")
    end,
}

function QRA.BossMods:SetupBigWigs()
    if not BigWigsLoader then
        QRA.Print("BigWigs not detected.")
        return nil
    end
    QRA.Print("BigWigs detected.")
    return bigWigs
end
