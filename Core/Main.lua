--[[
    QRaidAssignments - Main Initialization
    Handles addon loading, event registration, and module initialization
]]

---@class addon: AceAddon, AceComm-3.0
local addon = LibStub("AceAddon-3.0"):NewAddon("QRaidAssignments", "AceComm-3.0")

---@type AbstractFramework
local AF = _G.AbstractFramework

---@class QRA
local QRA = QRA

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
-- QRA.Debug = AF.Debug

--------------------------------------------------
-- Utility Functions
--------------------------------------------------

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

--- Deep copy a table
---@param orig table
---@return table
function QRA.DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for key, value in pairs(orig) do
            copy[QRA.DeepCopy(key)] = QRA.DeepCopy(value)
        end
        setmetatable(copy, QRA.DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

--- Serialize data for export (simple implementation)
---@param data any
---@return string|nil
function QRA.Serialize(data)
    -- Use AceSerializer if available, otherwise simple implementation
    local AceSerializer = LibStub and LibStub("AceSerializer-3.0", true)
    if AceSerializer then
        return AceSerializer:Serialize(data)
    end

    -- Fallback: simple table to string (not fully featured)
    if type(data) == "table" then
        local parts = {}
        for k, v in pairs(data) do
            local key = type(k) == "string" and string.format("[%q]", k) or string.format("[%s]", tostring(k))
            local val
            if type(v) == "string" then
                val = string.format("%q", v)
            elseif type(v) == "table" then
                val = QRA.Serialize(v)
            else
                val = tostring(v)
            end
            table.insert(parts, key .. "=" .. val)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return tostring(data)
end

--- Deserialize data from import
---@param str string
---@return boolean success
---@return any data
function QRA.Deserialize(str)
    local AceSerializer = LibStub and LibStub("AceSerializer-3.0", true)
    if AceSerializer then
        return AceSerializer:Deserialize(str)
    end

    -- Fallback: loadstring (less safe, but works for simple cases)
    local func, err = loadstring("return " .. str)
    if func then
        local success, result = pcall(func)
        return success, result
    end
    return false, err
end

--------------------------------------------------
-- UI Parent Frame
--------------------------------------------------

QRA.UIParent = CreateFrame("Frame", "QRA_Parent", UIParent)
QRA.UIParent:SetAllPoints(UIParent)
QRA.UIParent:SetFrameLevel(0)

--------------------------------------------------
-- Event Handling
--------------------------------------------------

QRA.UIParent:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

--------------------------------------------------
-- ADDON_LOADED
--------------------------------------------------
function addon:OnInitialize()
    -- Register with AbstractFramework
    AF.RegisterAddon(QRA.name, "Q's Raid Assignments")
    AF.SetAddonAccentColor(QRA.name, "softlime")

    QRA.Print("Loaded.")
end

function addon:OnEnable()
    -- Initialize saved variables
    if not QRA_DB then
        QRA_DB = {
            assignments = {},
            templates = {},
            triggers = {},
            notifications = {},
            settings = {
                debug = false,
            }
        }
    end
    QRA.DB = QRA_DB
    QRA.Settings = QRA.DB.settings
    -- AFConfig.debug[QRA.name] = QRA.Settings.debug

    -- Initialize all modules
    QRA.InitializeModules()

    -- Register combat log event
    -- self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

    -- Register encounter events
    -- self:RegisterEvent("ENCOUNTER_START")
    -- self:RegisterEvent("ENCOUNTER_END")

    -- Register zone chnage event
    QRA.UIParent:RegisterEvent("ZONE_CHANGED")
    -- addon:RegisterEvent("ZONE_CHANGED_INDOORS", QRA.UIParent.ZONE_CHANGED_INDOORS)
    -- addon:RegisterEvent("PLAYER_LOGIN", QRA.UIParent.PLAYER_LOGIN)

    QRA.Debug("All modules initialized")
end

-- QRA.UIParent:RegisterEvent("ADDON_LOADED")
-- function QRA.UIParent:ADDON_LOADED(addon)
--     if addon ~= QRA.name then return end
--     self:UnregisterEvent("ADDON_LOADED")

--     -- Register with AbstractFramework
--     AF.RegisterAddon(QRA.name, "Q's Raid Assignments")
--     AF.SetAddonAccentColor(QRA.name, "softlime")

--     QRA.Print("Loaded.")
-- end

--------------------------------------------------
-- PLAYER_LOGIN
--------------------------------------------------

-- QRA.UIParent:RegisterEvent("PLAYER_LOGIN")
-- function QRA.UIParent:PLAYER_LOGIN()
--     self:UnregisterEvent("PLAYER_LOGIN")

--     -- Initialize saved variables
--     if not QRA_DB then
--         QRA_DB = {
--             assignments = {},
--             templates = {},
--             triggers = {},
--             notifications = {},
--             settings = {
--                 debug = false,
--             }
--         }
--     end
--     QRA.DB = QRA_DB
--     QRA.Settings = QRA.DB.settings
--     -- AFConfig.debug[QRA.name] = QRA.Settings.debug

--     -- Initialize all modules
--     QRA.InitializeModules()

--     -- Register combat log event
--     -- self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

--     -- Register encounter events
--     -- self:RegisterEvent("ENCOUNTER_START")
--     -- self:RegisterEvent("ENCOUNTER_END")

--     -- Register zone chnage event
--     -- self:RegisterEvent("ZONE_CHANGED")
--     self:RegisterEvent("ZONE_CHANGED_INDOORS")

--     QRA.Debug("All modules initialized")
-- end

--------------------------------------------------
-- Module Initialization
--------------------------------------------------
function QRA.InitializeModules()
    -- Initialize in dependency order
    if QRA.Widgets and QRA.Widgets.Initialize then
        QRA.Widgets.Initialize()
    end

    if QRA.Notifications and QRA.Notifications.Initialize then
        QRA.Notifications.Initialize()
    end

    -- Initialize Raid Roster (for assignment targets)
    if QRA.RaidRoster and QRA.RaidRoster.Initialize then
        QRA.RaidRoster.Initialize()
    end

    if QRA.Triggers and QRA.Triggers.Initialize then
        QRA.Triggers.Initialize()
    end

    if QRA.Assignments and QRA.Assignments.Initialize then
        QRA.Assignments.Initialize()
    end

    -- if QRA.Templates and QRA.Templates.Initialize then
    --     QRA.Templates.Initialize()
    -- end

    if QRA.UI and QRA.UI.Initialize then
        QRA.UI.Initialize()
    end

    if QRA.Comm and QRA.Comm.Initialize then
        QRA.Comm.Initialize()
    end

    -- Initialize DevMode
    if QRA.DevMode and QRA.DevMode.Initialize then
        QRA.DevMode.Initialize()
    end

    -- Initialize DevMode EventHistory
    if QRA.DevMode and QRA.DevMode.EventHistory and QRA.DevMode.EventHistory.Initialize then
        QRA.DevMode.EventHistory.Initialize()
    end
end

---------------------------------------------------
-- ZONE_CHANGED
---------------------------------------------------

function QRA.UIParent:ZONE_CHANGED()
    QRA.Debug("ZONE_CHANGED: " .. (GetZoneText() or "Unknown") .. " - " .. (GetSubZoneText() or "Unknown"))
end

function QRA.UIParent:ZONE_CHANGED_INDOORS()
    QRA.Debug("ZONE_CHANGED_INDOORS: " .. (GetZoneText() or "Unknown") .. " - " .. (GetSubZoneText() or "Unknown"))
end

--------------------------------------------------
-- PLAYER_LOGOUT - Save data
--------------------------------------------------

QRA.UIParent:RegisterEvent("PLAYER_LOGOUT")
function QRA.UIParent:PLAYER_LOGOUT()
    -- Ensure all data is saved
    if QRA.Assignments and QRA.Assignments.SaveToDB then
        QRA.Assignments.SaveToDB()
    end
    -- if QRA.Templates and QRA.Templates.SaveToDB then
    --     QRA.Templates.SaveToDB()
    -- end
    if QRA.Notifications and QRA.Notifications.SaveToDB then
        QRA.Notifications.SaveToDB()
    end
    if QRA.RaidRoster and QRA.RaidRoster.SaveToDB then
        QRA.RaidRoster.SaveToDB()
    end
end

--------------------------------------------------
-- SLASH COMMANDS
--------------------------------------------------

_G["SLASH_QRAASSIGNMENTS1"] = "/qra"
_G["SLASH_QRAASSIGNMENTS2"] = "/qraid"

SlashCmdList.QRAASSIGNMENTS = function(msg)
    msg = msg and msg:lower():trim() or ""

    if msg == "" or msg == "show" then
        QRA.UI.Toggle()
    elseif msg == "help" then
        QRA.Print("Commands:")
        QRA.Print("  /qra - Toggle main window")
        QRA.Print("  /qra show - Show main window")
        QRA.Print("  /qra hide - Hide main window")
        QRA.Print("  /qra test - Test notifications")
        QRA.Print("  /qra devmode - Toggle dev/test mode")
        QRA.Print("  /qra debug - Toggle debug mode")
    elseif msg == "hide" then
        QRA.UI.HideMainFrame()
    elseif msg == "test" then
        QRA.Notifications.TestCountdown()
    elseif msg == "devmode" or msg == "dev" or msg == "testmode" then
        if QRA.DevMode then
            if QRA.DevMode.IsActive() then
                QRA.DevMode.Disable()
                QRA.Print("Dev Mode: Disabled")
            else
                QRA.DevMode.Enable()
                QRA.Print("Dev Mode: Enabled")
                if QRA.DevMode.UI and QRA.DevMode.UI.ShowTestPanel then
                    QRA.DevMode.UI.ShowTestPanel()
                end
            end
        end
    elseif msg == "debug" then
        QRA.Settings.debug = not QRA.Settings.debug
        -- if AFConfig then
        --     AFConfig.debug[QRA.name] = QRA.Settings.debug
        -- end
        QRA.Print("Debug mode:", QRA.Settings.debug and "ON" or "OFF")
    else
        QRA.Print("Unknown command. Use /qra help for available commands.")
    end
end
