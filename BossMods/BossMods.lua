---@class QRA
local QRA = QRA

QRA.BossMods = QRA.BossMods or {}

local bossModsFrame = CreateFrame("Frame")

---@type QRA_BigWigs | QRA_DBM | nil
local BossMod = nil
local bw, dbm

local function ENCOUNTER_START(_, _, encounterId, encounterName)
    QRA.Debug("BossMods: Encounter started:", encounterName, "ID:", encounterId)
    if bw then
        bw:RegisterStage()
    end
    if dbm then
        dbm:RegisterStage()
    end

    if QRA.Triggers and QRA.Triggers.OnEncounterStart then
        QRA.Triggers.OnEncounterStart(encounterId, encounterName)
    end
end

local function ENCOUNTER_END(_, _, encounterId, encounterName, _, _, success)
    QRA.Debug("BossMods: Encounter ended:", encounterName, "ID:", encounterId, "Success:", success)

    if QRA.Triggers and QRA.Triggers.OnEncounterEnd then
        QRA.Triggers.OnEncounterEnd(encounterId, encounterName, success)
    end
end

do
    bossModsFrame:RegisterEvent("ENCOUNTER_START")
    bossModsFrame:RegisterEvent("ENCOUNTER_END")

    bossModsFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "ENCOUNTER_START" then
            ENCOUNTER_START(self, event, ...)
        elseif event == "ENCOUNTER_END" then
            ENCOUNTER_END(self, event, ...)
        end
    end)
end

function QRA.BossMods.Initialize()
    bw = QRA.BossMods:SetupBigWigs()
    dbm = QRA.BossMods:SetupDBM()

    -- if bw then
    --     BossMod = bw
    --     return
    -- end
    -- if dbm then
    --     BossMod = dbm
    --     return
    -- end
    if not bw and not dbm then
        QRA.Print("No supported boss mod detected. Boss mod integration disabled.")
        return
    end

    QRA.Debug("BossMods: Module initialized")
end
