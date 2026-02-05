--[[
    QRaidAssignments - Main Initialization
    Handles addon loading, event registration, and module initialization
]]


---@class QRA
local QRA = select(2, ...)

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
            notes = {},
            settings = {
                debug = false,
                lastSeenVersion = nil,
                hideChangelogUntilNextVersion = false,
                assignmentDisplay = {
                    enabled = true,
                    position = {
                        point = "CENTER",
                        xOfs = 0,
                        yOfs = 0,
                    }
                },
                noteFrame = {
                    position = {
                        point = "CENTER",
                        xOfs = -300,
                        yOfs = 0,
                    }
                }
            }
        }
    end
    QRA.DB = QRA_DB
    QRA.Settings = QRA.DB.settings

    -- Ensure new fields exist in existing saves
    if not QRA.DB.notes then
        QRA.DB.notes = {}
    end
    if not QRA.Settings.assignmentDisplay then
        QRA.Settings.assignmentDisplay = {
            enabled = true,
            position = {
                point = "CENTER",
                xOfs = 0,
                yOfs = 0,
            }
        }
    end
    if not QRA.Settings.noteFrame then
        QRA.Settings.noteFrame = {
            position = {
                point = "CENTER",
                xOfs = -300,
                yOfs = 0,
            }
        }
    end

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
    if QRA.Logger and QRA.Logger.LoadLogs then
        QRA.Logger.LoadLogs()
    end

    if QRA.Widgets and QRA.Widgets.Initialize then
        QRA.Widgets.Initialize()
    end

    if QRA.Notifications and QRA.Notifications.Initialize then
        QRA.Notifications.Initialize()
    end

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

    if QRA.UI and QRA.UI.Initialize then
        QRA.UI.Initialize()
    end

    if QRA.Changelog and QRA.Changelog.Initialize then
        QRA.Changelog.Initialize()
    end

    if QRA.Comm and QRA.Comm.Initialize then
        QRA.Comm.Initialize()
    end

    if QRA.Notes and QRA.Notes.Initialize then
        QRA.Notes.Initialize()
    end

    if QRA.AssignmentDisplay and QRA.AssignmentDisplay.Initialize then
        QRA.AssignmentDisplay.Initialize()
    end

    -- Initialize DevMode
    if QRA.DevMode and QRA.DevMode.Initialize then
        QRA.DevMode.Initialize()
    end

    -- Initialize DevMode EventHistory
    if QRA.DevMode and QRA.DevMode.EventHistory and QRA.DevMode.EventHistory.Initialize then
        QRA.DevMode.EventHistory.Initialize()
    end

    -- Register zone change events
    QRA.UIParent:RegisterEvent("ZONE_CHANGED_INDOORS")
    QRA.UIParent:RegisterEvent("ZONE_CHANGED")
end

---------------------------------------------------
-- ZONE_CHANGED
---------------------------------------------------

function QRA.UIParent:ZONE_CHANGED()
    local zoneName = GetZoneText() or ""
    local subZone = GetSubZoneText() or ""
    QRA.Debug("ZONE_CHANGED:", zoneName, "-", subZone)

    -- Check if we're in a boss zone
    QRA.CheckBossZone()
end

function QRA.UIParent:ZONE_CHANGED_INDOORS()
    local zoneName = GetZoneText() or ""
    local subZone = GetSubZoneText() or ""
    QRA.Debug("ZONE_CHANGED_INDOORS:", zoneName, "-", subZone)

    -- Check if we're in a boss zone
    QRA.CheckBossZone()
end

--- Check if player is in a boss zone and show/hide UI accordingly
---@param forcedBossData? table Optional boss data to use (for DevMode)
function QRA.CheckBossZone(forcedBossData)
    local bossData = forcedBossData

    -- If not forced (DevMode), check actual zone
    if not bossData then
        local zoneName = GetZoneText()
        local subZone = GetSubZoneText()

        -- Try both zone and subzone
        if subZone and subZone ~= "" then
            bossData = QRA.Bosses.GetBossByZoneName(subZone)
        end
        if not bossData and zoneName and zoneName ~= "" then
            bossData = QRA.Bosses.GetBossByZoneName(zoneName)
        end
    end

    if bossData then
        QRA.Debug("Entered boss zone:", bossData.name)

        -- Show note frame
        if QRA.Notes then
            QRA.Notes.ShowForEncounter(bossData.encounterId, bossData.name)
        end

        -- Show assignment display if enabled
        if QRA.AssignmentDisplay and QRA.Settings.assignmentDisplay.enabled then
            QRA.AssignmentDisplay.ShowForEncounter(bossData.encounterId, bossData.name)
        end
    else
        QRA.Debug("Left boss zone")

        -- Hide both frames
        if QRA.Notes then
            QRA.Notes.Hide()
        end
        if QRA.AssignmentDisplay then
            QRA.AssignmentDisplay.Hide()
        end
    end
end

--------------------------------------------------
-- PLAYER_LOGOUT - Save data
--------------------------------------------------

QRA.UIParent:RegisterEvent("PLAYER_LOGOUT")
function QRA.UIParent:PLAYER_LOGOUT()
    if QRA.Logger and QRA.Logger.SaveLogs then
        QRA.Debug("Saving logs to DB")
        QRA.Logger.SaveLogs()
    end
    if QRA.Assignments and QRA.Assignments.SaveToDB then
        QRA.Assignments.SaveToDB()
    end
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
        QRA.Print("  /qra logs - Toggle log viewer")
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
    elseif msg == "logs" then
        if QRA.Logger and QRA.Logger.ToggleLogFrame then
            QRA.Logger.ToggleLogFrame()
        end
    else
        QRA.Print("Unknown command. Use /qra help for available commands.")
    end
end
