--[[
    QRaidAssignments - Localization (English US)
    All localized strings for the addon
]]

---@class QRA
local QRA = select(2, ...)
if not QRA then return end  -- Safety check

QRA.L = QRA.L or {}

-- Use a metatable to return the key if no translation exists
setmetatable(QRA.L, {
    __index = function(t, key)
        return key
    end
})

local L = QRA.L

--------------------------------------------------
-- General
--------------------------------------------------
L["Q's Raid Assignments"] = "Q's Raid Assignments"
L["Loaded."] = "Loaded."
L["Save"] = "Save"
L["Cancel"] = "Cancel"
L["Delete"] = "Delete"
L["Edit"] = "Edit"
L["Apply"] = "Apply"
L["Close"] = "Close"
L["OK"] = "OK"
L["Yes"] = "Yes"
L["No"] = "No"
L["All"] = "All"
L["None"] = "None"
L["Enabled"] = "Enabled"
L["Disabled"] = "Disabled"
L["Unknown"] = "Unknown"

--------------------------------------------------
-- Tabs
--------------------------------------------------
L["Assignments"] = "Assignments"
L["Triggers"] = "Triggers"
L["Templates"] = "Templates"
L["Settings"] = "Settings"

--------------------------------------------------
-- Assignments
--------------------------------------------------
L["Raid Assignments"] = "Raid Assignments"
L["+ Add Assignment"] = "+ Add Assignment"
L["New Assignment"] = "New Assignment"
L["Edit Assignment"] = "Edit Assignment"
L["Assignment Editor"] = "Assignment Editor"
L["Unknown Assignment"] = "Unknown Assignment"
L["Spell/Action"] = "Spell/Action"
L["Trigger"] = "Trigger"
L["CD"] = "CD"
L["Spell"] = "Spell"
L["Spell ID"] = "Spell ID"
L["Message (optional)"] = "Message (optional)"
L["Target (optional)"] = "Target (optional)"
L["Countdown (sec)"] = "Countdown (sec)"
L["Alert Type"] = "Alert Type"

-- Assign Target
L["Assign To"] = "Assign To"
L["-- Select Target --"] = "-- Select Target --"
L["Roster"] = "Roster"
L["All"] = "All"
L["By Role"] = "By Role"
L["By Class/Spec"] = "By Class/Spec"
L["Specific Player"] = "Specific Player"
L["Tank"] = "Tank"
L["Healer"] = "Healer"
L["DPS"] = "DPS"
L["Any"] = "Any"

--------------------------------------------------
-- Alert Types
--------------------------------------------------
L["Text-to-Speech"] = "Text-to-Speech"
L["Sound"] = "Sound"
L["On-Screen Text"] = "On-Screen Text"
L["Chat Message"] = "Chat Message"

--------------------------------------------------
-- Triggers
--------------------------------------------------
L["Encounter Triggers"] = "Encounter Triggers"
L["+ Add Trigger"] = "+ Add Trigger"
L["New Trigger"] = "New Trigger"
L["Edit Trigger"] = "Edit Trigger"
L["Trigger Editor"] = "Trigger Editor"
L["Trigger Type"] = "Trigger Type"
L["Type"] = "Type"
L["Details"] = "Details"
L["Counter"] = "Counter"
L["Activate In (seconds)"] = "Activate In (seconds)"
L["Time (seconds)"] = "Time (seconds)"
L["Interval (seconds)"] = "Interval (seconds)"
L["Repeat Count"] = "Repeat Count"
L["NPC ID"] = "NPC ID"
L["triggers"] = "triggers"
L["Boss/Encounter"] = "Boss/Encounter"
L["All Bosses"] = "All Bosses"
L["General"] = "General"
L["-- No Trigger --"] = "-- No Trigger --"
L["Select Trigger"] = "Select Trigger"
L["Linked Trigger"] = "Linked Trigger"
L["Manage Templates"] = "Manage Templates"
L["Plan"] = "Plan"
L["New Plan"] = "New Plan"
L["+ New Plan"] = "+ New Plan"
L["Set Active"] = "Set Active"
L["Plan Name (optional)"] = "Plan Name (optional)"
L["Instance"] = "Instance"
L["-- Select Instance --"] = "-- Select Instance --"
L["-- Select Plan --"] = "-- Select Plan --"
L["All Bosses"] = "All Bosses"
L["Please select an instance."] = "Please select an instance."
L["Main Plan"] = "Main Plan"
L["Plan Editor"] = "Plan Editor"
L["Personal"] = "Personal"
L["New Version"] = "New Version"
L["Source Plan"] = "Source Plan"
L["Please select a source plan."] = "Please select a source plan."
L["Create a new empty version on Personal plan"] = "Create a new empty version on Personal plan"
L["Clone"] = "Clone"
L["Clone active version of selected source plan"] = "Clone active version of selected source plan"
L["Delete Plan"] = "Delete Plan"
L["Delete Version"] = "Delete Version"
L["Delete plan '%s' and all data?"] = "Delete plan '%s' and all data?"
L["Delete %s from '%s'?"] = "Delete %s from '%s'?"
L["Personal plan cannot be deleted."] = "Personal plan cannot be deleted."
L["Plan not found."] = "Plan not found."
L["Failed to delete plan/version."] = "Failed to delete plan/version."
L["Raid Notes"] = "Raid Notes"
L["Notes:"] = "Notes:"
L["Note saved."] = "Note saved."
L["Note successfully sent to raid."] = "Note successfully sent to raid."
L["Failed to send note to raid."] = "Failed to send note to raid."
L["Notes successfully sent to raid."] = "Notes successfully sent to raid."
L["Failed to send notes to raid."] = "Failed to send notes to raid."
L["You must be in a raid group to send notes."] = "You must be in a raid group to send notes."
L["You must be the raid leader or an assistant to send notes."] = "You must be the raid leader or an assistant to send notes."
L["Note Config"] = "Note Config"
L["Open Note Config"] = "Open Note Config"
L["Enable Note"] = "Enable Note"
L["Push Notes to Raid"] = "Push Notes to Raid"
L["Note Font"] = "Note Font"
L["Note Font Size"] = "Note Font Size"
L["Note Line Spacing"] = "Note Line Spacing"
L["Raid Note Background Opacity"] = "Raid Note Background Opacity"
L["Personal Note Background Opacity"] = "Personal Note Background Opacity"
L["Boss Note"] = "Boss Note"
L["Please select a boss note."] = "Please select a boss note."
L["Note Frame"] = "Note Frame"
L["No boss note selected"] = "No boss note selected"
L["Insert Class Color"] = "Insert Class Color"
L["-- Select Class --"] = "-- Select Class --"
L["Insert icons and class colors into note"] = "Insert icons and class colors into note"
L["Personal Note"] = "Personal Note"
L["Personal Note:"] = "Personal Note:"
L["Personal Note Frame"] = "Personal Note Frame"
L["Enable Personal Note"] = "Enable Personal Note"
L["Notes are disabled."] = "Notes are disabled. Can't toggle personal note."
L["Encounter Only"] = "Encounter Only"

-- Trigger Types
L["Spell Cast Success"] = "Spell Cast Success"
L["Spell Cast Start"] = "Spell Cast Start"
L["Aura Applied"] = "Aura Applied"
L["Aura Removed"] = "Aura Removed"
L["Timer"] = "Timer"
L["NPC Death"] = "NPC Death"
L["Unit HP %"] = "Unit HP %"
L["HP Thresholds (%)"] = "HP Thresholds (%)"
L["Target Unit/NPC ID"] = "Target Unit/NPC ID"

--------------------------------------------------
-- Export/Import
--------------------------------------------------
L["Export"] = "Export"
L["Import"] = "Import"
L["Send to Raid"] = "Send to Raid"

--------------------------------------------------
-- Settings
--------------------------------------------------
L["Settings"] = "Settings"
L["Notification Settings"] = "Notification Settings"
L["Enable Text-to-Speech"] = "Enable Text-to-Speech"
L["Enable Sounds"] = "Enable Sounds"
L["Enable On-Screen Messages"] = "Enable On-Screen Messages"
L["Enable Chat Messages"] = "Enable Chat Messages"
L["Test Notifications"] = "Test Notifications"
L["Test TTS"] = "Test TTS"
L["Test Sound"] = "Test Sound"
L["Test Screen"] = "Test Screen"
L["Test Countdown"] = "Test Countdown"
L["Test Alert"] = "Test Alert"
L["Debug"] = "Debug"
L["Enable Debug Mode"] = "Enable Debug Mode"
L["Reset Note Frame"] = "Reset Note Frame"

--------------------------------------------------
-- Hierarchical Tree View
--------------------------------------------------
L["Orphaned Assignments"] = "Orphaned Assignments"
L["No Trigger"] = "No Trigger"
L["Assign to Trigger"] = "Assign to Trigger"
L["Add Assignment"] = "Add Assignment"
L["Delete Trigger"] = "Delete Trigger"
L["Delete Assignment"] = "Delete Assignment"
L["This trigger has %d assignment(s)"] = "This trigger has %d assignment(s)"
L["Delete All"] = "Delete All"
L["Keep as Orphaned"] = "Keep as Orphaned"
L["What would you like to do with the assignments?"] = "What would you like to do with the assignments?"
L["Expand All"] = "Expand All"
L["Collapse All"] = "Collapse All"
L["All Instances"] = "All Instances"
L["Delete Boss Data"] = "Delete Boss Data"
L["Delete all triggers and assignments for %s?"] = "Delete all triggers and assignments for %s?"
L["Delete All Data"] = "Delete All Data"
L["Delete ALL triggers and assignments?"] = "Delete ALL plans, triggers, and assignments?"
L["This cannot be undone."] = "This cannot be undone."
L["Confirm"] = "Confirm"

--------------------------------------------------
-- Notifications
--------------------------------------------------
L["in %d seconds"] = "in %d seconds"
L["NOW!"] = "NOW!"
L["Assignment"] = "Assignment"
L["Use %s"] = "Use %s"
L["Use %s on %s"] = "Use %s on %s"

--------------------------------------------------
-- Errors/Warnings
--------------------------------------------------
L["Invalid trigger"] = "Invalid trigger"
L["Invalid assignment"] = "Invalid assignment"
L["Template not found"] = "Template not found"
L["Failed to import template"] = "Failed to import template"

--------------------------------------------------
-- Changelog
--------------------------------------------------
L["What's New in QRaidAssignments"] = "What's New in QRaidAssignments"
L["Version %s"] = "Version %s"
L["Don't show until next version"] = "Don't show until next version"

--------------------------------------------------
-- Dev Mode
--------------------------------------------------
L["Test Mode"] = "Test Mode"
L["DevMode: Test Panel"] = "DevMode: Test Panel"
L["DevMode: Fake Boss Simulator"] = "DevMode: Fake Boss Simulator"
L["DevMode: Event Log"] = "DevMode: Event Log"
L["Select Boss:"] = "Select Boss:"
L["Encounter:"] = "Encounter:"
L["Start Encounter"] = "Start Encounter"
L["Stop Encounter"] = "Stop Encounter"
L["Active:"] = "Active:"
L["Inactive"] = "Inactive"
L["Registered Triggers:"] = "Registered Triggers:"
L["Fire"] = "Fire"
L["Reset Counters"] = "Reset Counters"
L["Fake Boss"] = "Fake Boss"
L["Event Log"] = "Event Log"
L["Exit Test Mode"] = "Exit Test Mode"
L["DevMode: Select a boss first"] = "DevMode: Select a boss first"
L["DevMode: Start an encounter first"] = "DevMode: Start an encounter first"
L["DevMode: Counters reset"] = "DevMode: Counters reset and triggers re-registered"
L["DevMode: Could not find encounter ID for boss:"] = "DevMode: Could not find encounter ID for boss:"
L["DevMode: Enter a valid spell ID"] = "DevMode: Enter a valid spell ID"
L["DevMode: Trigger not found"] = "DevMode: Trigger not found"
L["DevMode: Not a timer trigger"] = "DevMode: Not a timer trigger"
L["DevMode: Use the Fake Boss panel to change HP"] = "DevMode: Use the Fake Boss panel to change HP"
L["DevMode: No events to save"] = "DevMode: No events to save"
L["Start an encounter to see boss frames"] = "Start an encounter to see boss frames"
L["Cast Spell"] = "Cast Spell"
L["Event Type"] = "Event Type"
L["Target Player"] = "Target Player"
L["Duration (sec)"] = "Duration (sec)"
L["Cast"] = "Cast"
L["Apply Debuff to Players"] = "Apply Debuff to Players"
L["Debuff Spell ID"] = "Debuff Spell ID"
L["Duration"] = "Duration"
L["Remove"] = "Remove"
L["Time"] = "Time"
L["Event"] = "Event"
L["events"] = "events"
L["Clear All"] = "Clear All"
L["Replay All"] = "Replay All"
L["Replay Fast"] = "Replay Fast"
L["TEST MODE"] = "TEST MODE"
