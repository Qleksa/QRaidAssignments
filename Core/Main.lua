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

    if not QRA_DB then
        QRA_DB = {
            assignments = {},
            templates = {},
            triggers = {},
            plans = {},
            notes = {},
            personalNote = {
                text = "",
                timestamp = time(),
                author = UnitName("player"),
            },
            notifications = {},
            settings = {
                debug = false,
                lastSeenVersion = nil,
                hideChangelogUntilNextVersion = false,
                noteFrame = {
                    position = {
                        point = "CENTER",
                        xOfs = -300,
                        yOfs = 0,
                    },
                    enabled = true,
                    fontName = "Noto_AP",
                    fontSize = 14,
                    lineSpacing = 2,
                },
                personalNoteFrame = {
                    position = {
                        point = "CENTER",
                        xOfs = 300,
                        yOfs = 0,
                    },
                    enabled = false,
                },
            }
        }
    end
    QRA.DB = QRA_DB
    QRA.Settings = QRA.DB.settings

    if not QRA.DB.notes then
        QRA.DB.notes = {}
    end

    if not QRA.Settings.noteFrame then
        QRA.Settings.noteFrame = {
            position = {
                point = "CENTER",
                xOfs = -300,
                yOfs = 0,
            },
            enabled = true,
            fontName = "Noto_AP",
            fontSize = 14,
            lineSpacing = 2,
        }
    end


    if QRA.Settings.hideChangelogUntilNextVersion == nil then
        QRA.Settings.hideChangelogUntilNextVersion = false
    end

    -- Initialize all modules

    QRA.InitializeModules()
    QRA.Debug("All modules initialized")

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

    if QRA.Plans and QRA.Plans.Initialize then
        QRA.Plans.Initialize()
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

    if QRA.DevMode and QRA.DevMode.Initialize then
        QRA.DevMode.Initialize()
    end

    if QRA.DevMode and QRA.DevMode.EventHistory and QRA.DevMode.EventHistory.Initialize then
        QRA.DevMode.EventHistory.Initialize()
    end

    QRA.UIParent:RegisterEvent("ZONE_CHANGED_INDOORS")
    QRA.UIParent:RegisterEvent("ZONE_CHANGED")
end

---------------------------------------------------
-- ZONE_CHANGED
---------------------------------------------------

function QRA.UIParent:ZONE_CHANGED()
    QRA.Debug("ZONE_CHANGED: " .. (GetZoneText() or "Unknown") .. " - " .. (GetSubZoneText() or "Unknown"))
    QRA.CheckBossZone()
end

function QRA.UIParent:ZONE_CHANGED_INDOORS()
    QRA.Debug("ZONE_CHANGED_INDOORS: " .. (GetZoneText() or "Unknown") .. " - " .. (GetSubZoneText() or "Unknown"))
    QRA.CheckBossZone()
end

---@param forcedBossData? BossData
function QRA.CheckBossZone(forcedBossData)
    if not QRA.Settings.noteFrame or not QRA.Settings.noteFrame.enabled then
        return
    end

    local bossData = forcedBossData

    if not bossData then
        local zoneName = GetZoneText()
        local subZone = GetSubZoneText()

        if subZone and subZone ~= "" then
            bossData = QRA.Bosses.GetBossByZoneName(subZone)
        end
        if not bossData and zoneName and zoneName ~= "" then
            bossData = QRA.Bosses.GetBossByZoneName(zoneName)
        end
    end

    if bossData then
        QRA.Debug("Entered boss zone:", bossData.name)
        if QRA.Notes then
            QRA.Notes.ShowForEncounter(bossData.encounterId, bossData.name)
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
        QRA.Print("  /qra note - Toggle notes display")
        QRA.Print("  /qra note config - Open note config")
        QRA.Print("  /qra note push - Push notes to raid")
        QRA.Print("  /qra pnote - Toggle personal note display")
        QRA.Print("  /qra pnote config - Open note config")
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
    elseif msg:find("^note") then
        local sub = msg:match("^note%s+(.+)$")
        if not sub or sub == "" then
            if QRA.Notes then
                local enabled = QRA.Notes.ToggleEnabled()
                QRA.Print(QRA.L["Notes:"], enabled and QRA.L["Enabled"] or QRA.L["Disabled"])
            end
        elseif sub == "config" then
            if QRA.Notes and QRA.Notes.ShowConfig then
                QRA.Notes.ShowConfig()
            end
        elseif sub == "push" then
            if QRA.Comm and QRA.Comm.SendNotesToRaid then
                QRA.Comm.SendNotesToRaid()
            end
        else
            QRA.Print("Unknown note command. Use /qra note, /qra note config, or /qra note push")
        end
    elseif msg:find("^pnote") then
        local sub = msg:match("^pnote%s+(.+)$")
        if not sub or sub == "" then
        if QRA.Notes and QRA.Notes.IsEnabled and not QRA.Notes.IsEnabled() then
                QRA.Print(QRA.L["Notes are disabled."])
        elseif QRA.Notes and QRA.Notes.TogglePersonalEnabled then
                local enabled = QRA.Notes.TogglePersonalEnabled()
                QRA.Print(QRA.L["Personal Note:"], enabled and QRA.L["Enabled"] or QRA.L["Disabled"])
            end
        elseif sub == "config" then
            if QRA.Notes and QRA.Notes.ShowConfig then
                QRA.Notes.ShowConfig(true)
            end
        else
            QRA.Print("Unknown personal note command. Use /qra pnote or /qra pnote config")
        end
    else
        QRA.Print("Unknown command. Use /qra help for available commands.")
    end
end
