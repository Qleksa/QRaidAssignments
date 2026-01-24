---@class QRA
local QRA = select(2, ...)

---@class QRA_BossMods | QRA_Module
QRA.BossMods = QRA.BossMods or {}

local bossModsFrame = CreateFrame("Frame")

---@type QRA_BigWigs | QRA_DBM | nil
local BossMod = nil
local bw, dbm

---@class QRA_Encounter
local encounter = nil

local function ENCOUNTER_START(encounterId, encounterName)
    QRA.Debug("BossMods: Encounter started:", encounterName, "ID:", encounterId)
    encounter = QRA.Encounter:NewEncounter(encounterName, encounterId)
    encounter:RegisterMessage(QRA.EncounterMessages.Start, function()
        QRA.Debug("Encounter: Message received - Start")
    end)
    encounter:RegisterMessage(QRA.EncounterMessages.SetPhase, function(_, phase)
        QRA.Debug("Encounter: Message received - SetPhase. New phase:", phase)
    end)
    encounter:RegisterMessage(QRA.EncounterMessages.End, function(_, success)
        QRA.Debug("Encounter: Message received - End. Success:", success)
    end)

    encounter:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    function encounter:UNIT_SPELLCAST_SUCCEEDED(unitTarget, castGUID, spellID)
        QRA.Debug("Encounter(callback) UNIT_SPELLCAST_SUCCEEDED Unit:", unitTarget, "SpellID:", spellID)
    end

    if QRA.Triggers and QRA.Triggers.OnEncounterStart then
        QRA.Triggers.OnEncounterStart(encounterId, encounterName)
    end
end

local function ENCOUNTER_END(encounterId, encounterName, _, _, success)
    encounter:End(success)

    QRA.Debug("BossMods: Encounter ended:", encounterName, "ID:", encounterId, "Success:", success)

    if QRA.Triggers and QRA.Triggers.OnEncounterEnd then
        QRA.Triggers.OnEncounterEnd(encounterId, encounterName, success)
    end
end

do
    bossModsFrame:RegisterEvent("ENCOUNTER_START")
    bossModsFrame:RegisterEvent("ENCOUNTER_END")

    bossModsFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "ENCOUNTER_START" then
            ENCOUNTER_START(...)
        elseif event == "ENCOUNTER_END" then
            ENCOUNTER_END(...)
        end
    end)
end

function QRA.BossMods.GetBossMod()
    return BossMod
end

function QRA.BossMods.Initialize()
    bw = QRA.BossMods:SetupBigWigs()
    dbm = QRA.BossMods:SetupDBM()

    -- if bw then
    --     BossMod = bw
    --     return
    -- end
    if dbm then
        BossMod = dbm
        return
    end
    if not bw and not dbm then
        QRA.Print("No supported boss mod detected. Boss mod integration disabled.")
        return
    end

    QRA.Debug("BossMods: Module initialized")
end
