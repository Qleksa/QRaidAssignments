--[[
    QRaidAssignments - Main Initialization
    Handles addon loading, event registration, and module initialization
]]


---@type AbstractFramework
local AF = _G.AbstractFramework

---@class QRA
local QRA = QRA

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
QRA.UIParent:RegisterEvent("ADDON_LOADED")
function QRA.UIParent:ADDON_LOADED(addon)
    if addon ~= QRA.name then return end
    self:UnregisterEvent("ADDON_LOADED")

    QRA.Print("v" .. QRA.version .. " loaded. Type /qra to open.")
end

--------------------------------------------------
-- PLAYER_LOGIN
--------------------------------------------------

QRA.UIParent:RegisterEvent("PLAYER_LOGIN")
function QRA.UIParent:PLAYER_LOGIN()
    self:UnregisterEvent("PLAYER_LOGIN")

    -- Initialize saved variables
    if not QRA_DB then
        QRA_DB = {
            assignments = {},
            templates = {},
            triggers = {},
            notifications = {},
            settings = {
                debug = false,
                lastSeenVersion = nil,
                hideChangelogUntilNextVersion = false,
            }
        }
    end
    QRA.DB = QRA_DB
    QRA.Settings = QRA.DB.settings

    -- Ensure new settings fields exist in existing saves (with proper defaults)
    if QRA.Settings.hideChangelogUntilNextVersion == nil then
        QRA.Settings.hideChangelogUntilNextVersion = false
    end
    -- lastSeenVersion is intentionally left nil for first-time users

    -- AFConfig.debug[QRA.name] = QRA.Settings.debug

    -- Initialize all modules
    QRA.InitializeModules()
    QRA.Debug("All modules initialized")

    -- Check and show changelog if needed (after all modules are ready)
    if QRA.Changelog and QRA.Changelog.CheckAndShow then
        QRA.Changelog.CheckAndShow()
    end
end

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

    if QRA.Bosses and QRA.Bosses.Initialize then
        QRA.Bosses.Initialize()
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

    if QRA.Changelog and QRA.Changelog.Initialize then
        QRA.Changelog.Initialize()
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
    elseif msg == "changelog" then
        if QRA.Changelog then
            QRA.Changelog.Show()
        end
    elseif msg == "help" then
        QRA.Print("Commands:")
        QRA.Print("  /qra - Toggle main window")
        QRA.Print("  /qra show - Show main window")
        QRA.Print("  /qra hide - Hide main window")
        QRA.Print("  /qra changelog - Show changelog window")
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
        QRA.Print("Debug mode:", QRA.Settings.debug and "ON" or "OFF")
    else
        QRA.Print("Unknown command. Use /qra help for available commands.")
    end
end
