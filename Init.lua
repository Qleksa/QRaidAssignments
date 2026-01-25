
---@type AbstractFramework
local AF = _G.AbstractFramework

---@class QRA
local QRA = select(2, ...)

---@alias QRA_Module table

QRA = QRA or {}

QRA.name = "QRaidAssignments"
QRA.version = "1.0.0"

--------------------------------------------------
-- Pre-initialize module tables
--------------------------------------------------

---@class QRA_Locale | QRA_Module
QRA.L = {}
---@class QRA_UI | QRA_Module
QRA.UI = {}
---@class QRA_Triggers | QRA_Module
QRA.Triggers = {}
---@class QRA_Assignments | QRA_Module
QRA.Assignments = {}
---@class QRA_Widgets | QRA_Module
QRA.Widgets = {}
---@class QRA_BossMods | QRA_Module
QRA.BossMods = {}
---@class QRA_Bosses | QRA_Module
QRA.Bosses = {}
---@class QRA_RaidRoster | QRA_Module
QRA.RaidRoster = {}
---@class QRA_Notifications | QRA_Module
QRA.Notifications = {}
---@class QRA_Comm | QRA_Module
QRA.Comm = {}
---@class QRA_DevMode | QRA_Module
QRA.DevMode = {}

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


---@class QRA_Event
---@field SendEvent fun(self: QRA_Module, event: string, ...: any)
---@field RegisterEvent fun(self: QRA_Module, event: string, callback: fun(event: string, ...: any), priority?: string, tag?: string)
---@field UnregisterEvent fun(self: QRA_Module, event: string, tag: string)
---@field UnregisterAllCallbacks fun(self: QRA_Module, event: string)
QRA.Event = {
    SendEvent = function (_, event, ...)
        AF.Fire(event, ...)
    end,
    RegisterEvent = function(_, event, callback, priority, tag)
        AF.RegisterCallback(event, callback, priority, tag)
    end,
    UnregisterEvent = function(_, event, tag)
        AF.UnregisterCallback(event, tag)
    end,
    UnregisterAllCallbacks = function(_, event)
        AF.UnregisterAllCallbacks(event)
    end,
}


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
---@field activateIn? string seconds to delay trigger activation with optional interval and repeat count (non-Timer triggers only)
---@field time? number seconds after pull
---@field repeatInterval? number seconds between repeats (Timer triggers only)
---@field repeatCount? number number of repeats (Timer triggers only)
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
---@field triggerId string? Parent trigger ID (nil for orphaned assignments)
---@field counterFormula string
---@field assignTarget string
---@field alertType AlertType
---@field countdownTime integer Seconds before alert
---@field activateIn? number Seconds to delay assignment activation after trigger fires
---@field spellId? number
---@field spellName? string
---@field targetPlayer? string
---@field message? string
---@field soundFile? string Custom sound file path
---@field createdAt integer

---@class OrphanedAssignment : Assignment
---@field orphanedAt integer Timestamp when assignment became orphaned
---@field previousTriggerId string? ID of the trigger that was deleted

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
