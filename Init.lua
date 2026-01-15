
---@type AbstractFramework
local AF = _G.AbstractFramework

---@class QRA
QRA = {}

QRA.name = "QRaidAssignments"
QRA.version = "0.1.0"

--------------------------------------------------
-- Pre-initialize module tables
--------------------------------------------------
QRA.L = {}
QRA.UI = {}
QRA.Triggers = {}
QRA.Assignments = {}
QRA.Templates = {}
QRA.Widgets = {}
QRA.Notifications = {}

--------------------------------------------------
-- APIs (from AbstractFramework)
--------------------------------------------------
QRA.Print = AF.Print
QRA.Serialize = AF.Serialize
QRA.Deserialize = AF.Deserialize
QRA.DeepCopy = AF.Copy
QRA.RegisterComm = AF.RegisterComm
QRA.SendCommMessage = AF.SendCommMessage_Group
QRA.DelayedInvoke = AF.DelayedInvoke

AF.RegisterAddon(QRA.name, "Q's Raid Assignments")
AF.SetAddonAccentColor(QRA.name, "softlime")

-- Types
---@class LibSerialize
---@field SerializeEx fun(self: LibSerialize, options: table, input: any): string
---@field Deserialize fun(self: LibSerialize, input: string): boolean, table

---@class Trigger
---@field id string
---@field type string
---@field version number default 1
---@field name string
---@field enabled boolean default true
---@field default boolean is trigger default for boss, false by default
---@field encounterId number
---@field bossName string
---@field counterFormula string
---@field activateIn? number seconds to delay trigger activation (non-Timer triggers only)
---@field time? number seconds after pull
---@field repeatInterval? number seconds between repeats (Timer triggers only)
---@field repeatCount? number number of repeats (Timer triggers only)
---@field npcName? string
---@field spellId? number
---@field spellName? string
---@field targetGuid? string
---@field hpThresholds? string comma separated list of hp thresholds
---@field assignments Assignment[]
---@field createdAt integer

---@alias AlertType
---| 'TTS'
---| 'SOUND'
---| 'SCREEN'
---| 'CHAT'

---@class Assignment
---@field id string
---@field version number
---@field enabled boolean
---@field triggerId string
---@field counterFormula string
---@field assignTarget string
---@field alertType AlertType
---@field countdownTime integer Seconds before alert
---@field spellId? number
---@field spellName? string
---@field targetPlayer? string
---@field message? string
---@field soundFile? string Custom sound file path
---@field createdAt integer

local areLibsOkay = true
do
    local libStubLibs = {
        "AceComm-3.0",
        "LibSerialize",
        "LibDeflate",
    }

    if LibStub then
        for _, lib in ipairs(libStubLibs) do
            if not LibStub:GetLibrary(lib, true) then
                areLibsOkay = false
                QRA.Print("Missing library:", lib)
            end
        end
    else
        areLibsOkay = false
        QRA.Print("Missing library: LibStub")
    end
end

function QRA.AreLibsOkay()
    return areLibsOkay
end

do
    if not areLibsOkay then
        QRA.Print("One or more required libraries are missing. Q's Raid Assignments will not function correctly.")
    end
end
