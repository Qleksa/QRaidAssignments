--[[
    QRaidAssignments - Notes UI
    Display-only encounter notes + config editor
]]

---@class QRA
local QRA = select(2, ...)

---@type AbstractFramework
local AF = _G.AbstractFramework

QRA.Notes = QRA.Notes or {}

local noteFrame = nil
local noteText = nil
local configFrame = nil

local currentEncounterId = nil
local currentBossName = nil

local MOVER_GROUP = "QRA Movers"

local RAID_ICON_INSERT_ORDER = {
    "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull",
}

local CLASS_COLOR_ITEMS = {
    { key = "NONE", text = "-- Select Class --", value = "__none__" },
    { key = "DEATHKNIGHT", text = "Death Knight", value = "|cffc41f3b" },
    { key = "DRUID", text = "Druid", value = "|cffff7d0a" },
    { key = "HUNTER", text = "Hunter", value = "|cffaad372" },
    { key = "MAGE", text = "Mage", value = "|cff3fc7eb" },
    { key = "MONK", text = "Monk", value = "|cff00ff98" },
    { key = "PALADIN", text = "Paladin", value = "|cfff48cba" },
    { key = "PRIEST", text = "Priest", value = "|cffffffff" },
    { key = "ROGUE", text = "Rogue", value = "|cfffff468" },
    { key = "SHAMAN", text = "Shaman", value = "|cff0070dd" },
    { key = "WARLOCK", text = "Warlock", value = "|cff8788ee" },
    { key = "WARRIOR", text = "Warrior", value = "|cffc69b6d" },
}

local function GetSettings()
    QRA.Settings.noteFrame = QRA.Settings.noteFrame or {}
    local settings = QRA.Settings.noteFrame

    settings.position = settings.position or {
        point = "CENTER",
        xOfs = -300,
        yOfs = 0,
    }

    if settings.enabled == nil then
        settings.enabled = true
    end

    settings.fontName = settings.fontName or "Noto_AP"
    settings.fontSize = tonumber(settings.fontSize) or 14
    settings.fontSize = math.max(8, math.min(30, settings.fontSize))
    settings.lineSpacing = tonumber(settings.lineSpacing) or 2
    settings.lineSpacing = math.max(0, math.min(20, settings.lineSpacing))

    return settings
end

local function UpdateNotePosition(point, x, y)
    local settings = GetSettings()
    settings.position.point = point
    settings.position.xOfs = x
    settings.position.yOfs = y

    if noteFrame then
        noteFrame:ClearAllPoints()
        AF.SetPoint(noteFrame, point, QRA.UIParent, x, y)
    end
end

---@param encounterId number
---@return string
local function GetNote(encounterId)
    if QRA.DB.notes and QRA.DB.notes[encounterId] then
        return QRA.DB.notes[encounterId].text or ""
    end

    return ""
end

---@param encounterId number
---@param text string
local function SaveNote(encounterId, text)
    QRA.DB.notes = QRA.DB.notes or {}

    QRA.DB.notes[encounterId] = {
        text = text or "",
        timestamp = time(),
        author = UnitName("player"),
    }
end

local function GetCurrentDisplayText()
    if not currentEncounterId then
        return QRA.L["No boss note selected"]
    end

    local raw = GetNote(currentEncounterId)
    if QRA.TextFormatter and QRA.TextFormatter.Format then
        return QRA.TextFormatter.Format(raw)
    end

    return raw
end

local function ApplyNoteFont()
    if not noteText then return end

    local settings = GetSettings()
    AF.SetFont(noteText, settings.fontName, settings.fontSize, "none", true)
    noteText:SetSpacing(settings.lineSpacing)
end

local function RefreshDisplayText()
    if not noteText then return end
    noteText:SetText(GetCurrentDisplayText())
end

local function EnsureNoteFrame()
    if noteFrame then
        return noteFrame
    end

    local settings = GetSettings()

    noteFrame = CreateFrame("Frame", "QRA_NoteFrame", QRA.UIParent)
    noteFrame:SetSize(460, 280)
    noteFrame:SetFrameStrata("MEDIUM")

    noteFrame:ClearAllPoints()
    AF.SetPoint(
        noteFrame,
        settings.position.point or "CENTER",
        QRA.UIParent,
        settings.position.xOfs or -300,
        settings.position.yOfs or 0
    )

    noteText = noteFrame:CreateFontString(nil, "OVERLAY")
    noteFrame.noteText = noteText
    AF.SetPoint(noteText, "TOPLEFT", noteFrame, 0, 0)
    AF.SetPoint(noteText, "TOPRIGHT", noteFrame, 0, 0)
    AF.SetPoint(noteText, "BOTTOMLEFT", noteFrame, 0, 0)
    AF.SetPoint(noteText, "BOTTOMRIGHT", noteFrame, 0, 0)
    noteText:SetJustifyH("LEFT")
    noteText:SetJustifyV("TOP")
    noteText:SetWordWrap(true)

    ApplyNoteFont()
    RefreshDisplayText()

    AF.CreateMover(noteFrame, MOVER_GROUP, QRA.L["Note Frame"], UpdateNotePosition)

    if settings.enabled then
        noteFrame:Show()
    else
        noteFrame:Hide()
    end

    return noteFrame
end

---@param encounterId number
---@param bossName string|nil
function QRA.Notes.SetEncounter(encounterId, bossName)
    if not encounterId then
        return
    end

    currentEncounterId = encounterId
    currentBossName = bossName

    EnsureNoteFrame()
    RefreshDisplayText()

    if configFrame and configFrame:IsShown() and configFrame.LoadEditorForEncounter then
        configFrame.LoadEditorForEncounter(encounterId, bossName)
    end
end

---@param encounterId number
function QRA.Notes.RefreshNote(encounterId)
    if not encounterId then return end
    if currentEncounterId ~= encounterId then return end

    EnsureNoteFrame()
    RefreshDisplayText()
end

---@param encounterId number
---@param bossName string|nil
function QRA.Notes.ShowForEncounter(encounterId, bossName)
    if not QRA.Notes.IsEnabled() then
        return
    end

    QRA.Notes.SetEncounter(encounterId, bossName)
    EnsureNoteFrame():Show()
end

function QRA.Notes.Hide()
    if noteFrame then
        noteFrame:Hide()
    end
end

---@return boolean
function QRA.Notes.IsVisible()
    return noteFrame ~= nil and noteFrame:IsShown()
end

---@return boolean
function QRA.Notes.IsEnabled()
    return GetSettings().enabled == true
end

---@param enabled boolean
function QRA.Notes.SetEnabled(enabled)
    local settings = GetSettings()
    settings.enabled = enabled == true

    EnsureNoteFrame()
    if settings.enabled then
        noteFrame:Show()
        if not currentEncounterId then
            QRA.CheckBossZone()
        end
        RefreshDisplayText()
    else
        noteFrame:Hide()
    end
end

---@return boolean
function QRA.Notes.ToggleEnabled()
    local enabled = not QRA.Notes.IsEnabled()
    QRA.Notes.SetEnabled(enabled)
    return enabled
end

---@return number|nil
function QRA.Notes.GetCurrentEncounter()
    return currentEncounterId
end

---@return string|nil
function QRA.Notes.GetCurrentBossName()
    return currentBossName
end

---@return table[]
local function GetBossItems()
    local items = {}
    local instances = QRA.Bosses.GetInstancesSortedByTier()

    for _, instanceInfo in ipairs(instances) do
        local entry = {
            text = instanceInfo.name,
            notClickable = true,
            children = {},
        }

        for _, bossData in ipairs(instanceInfo.data.bosses) do
            table.insert(entry.children, {
                text = bossData.name,
                value = bossData.encounterId,
                bossName = bossData.name,
            })
        end

        table.insert(items, entry)
    end

    return items
end

local function GetInitialEncounterForConfig()
    if currentEncounterId then
        return currentEncounterId
    end

    local sorted = QRA.Bosses.GetInstancesSortedByTier()
    if sorted[1] and sorted[1].data and sorted[1].data.bosses and sorted[1].data.bosses[1] then
        return sorted[1].data.bosses[1].encounterId
    end

    return nil
end

local function ShowConfigFrame()
    EnsureNoteFrame()

    if configFrame then
        configFrame.noteEnabledCheck:SetChecked(QRA.Notes.IsEnabled())
        configFrame.fontDropdown:SetSelectedValue(GetSettings().fontName)
        configFrame.fontSizeSlider:SetValue(GetSettings().fontSize)
        configFrame.lineSpacingSlider:SetValue(GetSettings().lineSpacing)
        configFrame:Show()
        return
    end

    configFrame = AF.CreateHeaderedFrame(
        QRA.UIParent,
        "QRA_NoteConfigFrame",
        QRA.L["Note Config"],
        560,
        665,
        "DIALOG",
        40
    )
    AF.SetPoint(configFrame, "CENTER", QRA.UIParent, 0, 0)
    table.insert(UISpecialFrames, configFrame:GetName())

    local content = CreateFrame("Frame", nil, configFrame)
    AF.SetPoint(content, "TOPLEFT", configFrame, 10, -10)
    AF.SetPoint(content, "BOTTOMRIGHT", configFrame, -10, 40)

    local noteEnabledCheck = AF.CreateCheckButton(content, QRA.L["Enable Notes"], function(checked)
        QRA.Notes.SetEnabled(checked)
    end)
    AF.SetPoint(noteEnabledCheck, "TOPLEFT", content, 0, 0)
    noteEnabledCheck:SetChecked(QRA.Notes.IsEnabled())
    configFrame.noteEnabledCheck = noteEnabledCheck

    local lockBtn = AF.CreateButton(content, QRA.L["Lock Note Frame"], "static", 120, 22)
    AF.SetPoint(lockBtn, "TOPRIGHT", content, 0, 0)
    lockBtn:SetOnClick(function()
        AF.HideMovers()
    end)

    local unlockBtn = AF.CreateButton(content, QRA.L["Unlock Note Frame"], "static", 130, 22)
    AF.SetPoint(unlockBtn, "RIGHT", lockBtn, "LEFT", -8, 0)
    unlockBtn:SetOnClick(function()
        AF.ShowMovers(MOVER_GROUP)
    end)

    local fontDropdown = AF.CreateDropdown(content, 250)
    fontDropdown:SetLabel(QRA.L["Note Font"])
    AF.SetPoint(fontDropdown, "TOPLEFT", noteEnabledCheck, "BOTTOMLEFT", 0, -25)
    fontDropdown:SetItems(AF.LSM_GetFontDropdownItems())

    local currentSettings = GetSettings()
    fontDropdown:SetSelectedValue(currentSettings.fontName)
    fontDropdown:SetOnSelect(function(value)
        currentSettings.fontName = value
        ApplyNoteFont()
    end)
    configFrame.fontDropdown = fontDropdown

    local fontSizeSlider = AF.CreateSlider(content, QRA.L["Note Font Size"], 220, 8, 30, 1)
    AF.SetPoint(fontSizeSlider, "LEFT", fontDropdown, "RIGHT", 18, 0)
    fontSizeSlider:SetValue(currentSettings.fontSize)
    fontSizeSlider:SetAfterValueChanged(function(value)
        currentSettings.fontSize = value
        ApplyNoteFont()
    end)
    configFrame.fontSizeSlider = fontSizeSlider

    local lineSpacingSlider = AF.CreateSlider(content, QRA.L["Note Line Spacing"], 220, 0, 20, 1)
    AF.SetPoint(lineSpacingSlider, "TOPLEFT", fontDropdown, "BOTTOMLEFT", 0, -20)
    lineSpacingSlider:SetValue(currentSettings.lineSpacing)
    lineSpacingSlider:SetAfterValueChanged(function(value)
        currentSettings.lineSpacing = value
        ApplyNoteFont()
    end)
    configFrame.lineSpacingSlider = lineSpacingSlider

    local bossDropdown = AF.CreateCascadingMenuButton(content, 520)
    bossDropdown:SetLabel(QRA.L["Boss"])
    AF.SetPoint(bossDropdown, "TOPLEFT", lineSpacingSlider, "BOTTOMLEFT", 0, -25)
    bossDropdown:SetItems(GetBossItems())

    local iconBar = CreateFrame("Frame", nil, content)
    AF.SetSize(iconBar, 520, 22)
    AF.SetPoint(iconBar, "TOPLEFT", bossDropdown, "BOTTOMLEFT", 0, -20)

    local editor = AF.CreateScrollEditBox(content, nil, QRA.L["Boss Note"], 520, 360)
    AF.SetPoint(editor, "TOPLEFT", iconBar, "BOTTOMLEFT", 0, -6)

    local selectedEncounterId = nil
    local selectedBossName = nil

    local function LoadEditorForEncounter(encounterId, bossName)
        selectedEncounterId = encounterId
        selectedBossName = bossName
        bossDropdown:SetText(bossName or QRA.L["-- Select Boss --"])
        editor:SetText(encounterId and GetNote(encounterId) or "")
        editor:SetCursorPosition(0)
    end
    configFrame.LoadEditorForEncounter = LoadEditorForEncounter

    local function InsertAtCursor(textToInsert)
        if not textToInsert or textToInsert == "" then return end
        editor:SetFocus()
        editor:Insert(textToInsert)
    end

    local function InsertAtPosition(textToInsert, position)
        if not textToInsert or textToInsert == "" then return end

        local editBox = editor and editor.eb
        if not editBox then return end

        local currentText = editBox:GetText() or ""
        local pos = position
        if type(pos) ~= "number" then
            pos = editBox:GetCursorPosition() or 0
        end

        local newText = string.sub(currentText, 1, pos) .. textToInsert .. string.sub(currentText, pos + 1)
        editor:SetText(newText)
        editBox:SetFocus()
        editBox:SetCursorPosition(pos + string.len(textToInsert))
    end

    local function GetSelectionRange(editBox)
        if not editBox then
            return nil, nil
        end

        if editBox.GetTextHighlight then
            return editBox:GetTextHighlight()
        end

        -- Some multiline editboxes (like AF) don't expose GetTextHighlight;
        -- emulate MRT's selection detection fallback.
        local text = editBox:GetText() or ""
        local cursor = editBox:GetCursorPosition() or 0

        editBox:Insert("")
        local textNew = editBox:GetText() or ""
        local cursorNew = editBox:GetCursorPosition() or cursor

        editBox:SetText(text)
        editBox:SetCursorPosition(cursor)

        local selectedStart = cursorNew
        local selectedEnd = #text - (#textNew - cursorNew)

        if type(selectedStart) ~= "number" or type(selectedEnd) ~= "number" then
            return nil, nil
        end

        selectedStart = math.max(0, math.min(selectedStart, #text))
        selectedEnd = math.max(0, math.min(selectedEnd, #text))
        editBox:HighlightText(selectedStart, selectedEnd)

        return selectedStart, selectedEnd
    end

    local function InsertClassColorCode(colorCode)
        if not colorCode or colorCode == "__none__" then return end

        local editBox = editor and editor.eb
        if not editBox then return end

        local selectedStart, selectedEnd = GetSelectionRange(editBox)
        local escapedColorCode = string.gsub(colorCode, "|", "||")

        if not selectedStart or not selectedEnd or selectedStart == selectedEnd then
            InsertAtPosition(escapedColorCode .. "||r")
            return
        end

        if selectedStart > selectedEnd then
            selectedStart, selectedEnd = selectedEnd, selectedStart
        end

        InsertAtPosition("||r", selectedEnd)
        InsertAtPosition(escapedColorCode, selectedStart)
    end

    local iconButtons = {}
    for index, iconName in ipairs(RAID_ICON_INSERT_ORDER) do
        local btn = AF.CreateButton(iconBar, " ", "static", 22, 22)
        if index == 1 then
            AF.SetPoint(btn, "LEFT", iconBar, 0, 0)
        else
            AF.SetPoint(btn, "LEFT", iconButtons[index - 1], "RIGHT", 2, 0)
        end

        local iconFS = AF.CreateFontString(btn, " ", "white")
        AF.SetPoint(iconFS, "CENTER", btn, 0, 0)
        iconFS:SetText(QRA.TextFormatter and QRA.TextFormatter.Format and QRA.TextFormatter.Format("{" .. iconName .. "}") or ("{" .. iconName .. "}"))

        btn:SetOnClick(function()
            InsertAtCursor("{" .. iconName .. "}")
        end)

        iconButtons[index] = btn
    end

    local classColorDropdown = AF.CreateDropdown(iconBar, 220)
    classColorDropdown:SetLabel(QRA.L["Insert Class Color"])
    AF.SetPoint(classColorDropdown, "LEFT", iconButtons[#iconButtons], "RIGHT", 12, 0)
    classColorDropdown:SetItems(CLASS_COLOR_ITEMS)
    classColorDropdown:SetSelectedValue("__none__")
    classColorDropdown:SetOnSelect(function(value)
        if value and value ~= "__none__" then
            InsertClassColorCode(value)
            classColorDropdown:SetSelectedValue("__none__")
        end
    end)

    local iconHint = AF.CreateFontString(iconBar, QRA.L["Insert icons and class colors into note"], "gray")
    AF.SetPoint(iconHint, "TOPLEFT", iconBar, "BOTTOMLEFT", 0, -4)

    hooksecurefunc(bossDropdown, "OnMenuSelection", function(_, item)
        if item and item.value then
            LoadEditorForEncounter(item.value, item.bossName or item.text)
        end
    end)

    local initialEncounter = GetInitialEncounterForConfig()
    if initialEncounter then
        local bossData = QRA.Bosses.GetBossByEncounterId(initialEncounter)
        LoadEditorForEncounter(initialEncounter, bossData and bossData.name or nil)
    end

    local saveBtn = AF.CreateButton(content, QRA.L["Save"], "softlime", 60, 24)
    AF.SetPoint(saveBtn, "TOPLEFT", editor, "BOTTOMLEFT", 0, -8)
    saveBtn:SetOnClick(function()
        if not selectedEncounterId then
            QRA.Print(QRA.L["Please select a boss note."])
            return
        end

        SaveNote(selectedEncounterId, editor:GetText() or "")
        QRA.Notes.RefreshNote(selectedEncounterId)
        if currentEncounterId == selectedEncounterId then
            QRA.Notes.SetEncounter(selectedEncounterId, selectedBossName)
        end
        QRA.Print(QRA.L["Note saved."])
    end)

    local pushBtn = AF.CreateButton(content, QRA.L["Push Notes to Raid"], "softblue", 135, 24)
    AF.SetPoint(pushBtn, "LEFT", saveBtn, "RIGHT", 8, 0)
    pushBtn:SetOnClick(function()
        if QRA.Comm and QRA.Comm.SendNotesToRaid then
            QRA.Comm.SendNotesToRaid()
        end
    end)

    local function RefreshPushButtonState()
        local canPush = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
        pushBtn:SetEnabled(canPush)
    end
    configFrame:SetScript("OnShow", RefreshPushButtonState)

    local closeBtn = AF.CreateButton(configFrame, QRA.L["Close"], "gray", 80, 26)
    AF.SetPoint(closeBtn, "BOTTOMRIGHT", configFrame, -10, 10)
    closeBtn:SetOnClick(function()
        configFrame:Hide()
    end)

    configFrame:Show()
end

function QRA.Notes.ShowConfig()
    ShowConfigFrame()
end

function QRA.Notes.GetAllRaw()
    QRA.DB.notes = QRA.DB.notes or {}
    return QRA.DB.notes
end

---@param incoming table
function QRA.Notes.ReplaceAll(incoming)
    QRA.DB.notes = {}

    for encounterId, noteData in pairs(incoming or {}) do
        local key = tonumber(encounterId) or encounterId
        QRA.DB.notes[key] = {
            text = (type(noteData) == "table" and noteData.text) or "",
            timestamp = (type(noteData) == "table" and noteData.timestamp) or time(),
            author = (type(noteData) == "table" and noteData.author) or UnitName("player"),
        }
    end

    if currentEncounterId then
        QRA.Notes.RefreshNote(currentEncounterId)
    end

    if configFrame and configFrame:IsShown() then
        configFrame:Hide()
        ShowConfigFrame()
    end
end

function QRA.Notes.Initialize()
    QRA.DB.notes = QRA.DB.notes or {}
    EnsureNoteFrame()

    if QRA.Notes.IsEnabled() then
        noteFrame:Show()
    else
        noteFrame:Hide()
    end

    QRA.Debug("Notes: Module Initialized")
end
