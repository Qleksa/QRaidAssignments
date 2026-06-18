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
local noteBackground = nil
local noteText = nil
local noteScrollFrame = nil
local noteContentFrame = nil
local noteResizeButton = nil
local configFrame = nil

local currentEncounterId = nil
local currentBossName = nil

local MOVER_GROUP = "QRA Movers"

local RAID_ICON_INSERT_ORDER = {
    "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull",
}

local PERSONAL_NOTE_KEY = "__personal_note__"
local IMAGE_BASE_PATH = "Interface\\AddOns\\QRaidAssignments\\Media\\Images\\"

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
    settings.backgroundAlpha = tonumber(settings.backgroundAlpha)
    if settings.backgroundAlpha == nil then
        settings.backgroundAlpha = 0.5
    end
    settings.backgroundAlpha = math.max(0, math.min(1, settings.backgroundAlpha))
    if settings.useImageBackground == nil then
        settings.useImageBackground = false
    end
    settings.backgroundImageName = tostring(settings.backgroundImageName or "")

    if type(settings.lastSelectedNote) ~= "table" then
        settings.lastSelectedNote = nil
    end

    settings.size = settings.size or { width = 460, height = 280 }
    settings.locked = settings.locked or false
    settings.encounterOnly = settings.encounterOnly or false

    return settings
end

---@param encounterId number|nil
---@param isPersonal boolean
local function RememberSelectedTarget(encounterId, isPersonal)
    local settings = GetSettings()

    if isPersonal then
        settings.lastSelectedNote = {
            type = "personal",
        }
        return
    end

    if encounterId then
        settings.lastSelectedNote = {
            type = "boss",
            encounterId = encounterId,
        }
    end
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

local function UpdateNoteContentHeight()
    if not noteContentFrame or not noteText or not noteScrollFrame then return end
    local w = noteScrollFrame:GetWidth()
    noteContentFrame:SetWidth(w)
    noteText:SetWidth(w)
    local th = noteText:GetStringHeight()
    noteContentFrame:SetHeight(math.max(th, noteScrollFrame:GetHeight()))
end

local function ApplyNoteFont()
    if not noteText then return end

    local settings = GetSettings()
    AF.SetFont(noteText, settings.fontName, settings.fontSize, "none", true)
    noteText:SetSpacing(settings.lineSpacing)

    if QRA.Notes.ApplyPersonalNoteFont then
        QRA.Notes.ApplyPersonalNoteFont(settings.fontName, settings.fontSize, settings.lineSpacing)
    end

    UpdateNoteContentHeight()
end

local function ApplyNoteBackgroundOpacity()
    if not noteBackground then return end
    local settings = GetSettings()

    noteBackground:SetTexture(nil)
    if settings.useImageBackground then
        local imageName = strtrim(settings.backgroundImageName or "")
        if imageName ~= "" then
            local imagePath = IMAGE_BASE_PATH .. imageName
            noteBackground:SetTexture(imagePath)
            if noteBackground:GetTexture() then
                noteBackground:SetVertexColor(1, 1, 1, settings.backgroundAlpha)
                return
            end
        end
    end

    noteBackground:SetColorTexture(0, 0, 0, settings.backgroundAlpha)
end

local function RefreshDisplayText()
    if not noteText then return end
    noteText:SetText(GetCurrentDisplayText())
    if noteScrollFrame then noteScrollFrame:SetVerticalScroll(0) end
    UpdateNoteContentHeight()
end

local function EnsureNoteFrame()
    if noteFrame then
        return noteFrame
    end

    local settings = GetSettings()
    local sz = settings.size

    noteFrame = CreateFrame("Frame", "QRA_NoteFrame", QRA.UIParent)
    noteFrame:SetSize(sz.width, sz.height)
    noteFrame:SetFrameStrata("MEDIUM")

    noteBackground = noteFrame:CreateTexture(nil, "BACKGROUND")
    noteBackground:SetAllPoints(noteFrame)
    ApplyNoteBackgroundOpacity()

    noteFrame:ClearAllPoints()
    AF.SetPoint(
        noteFrame,
        settings.position.point or "CENTER",
        QRA.UIParent,
        settings.position.xOfs or -300,
        settings.position.yOfs or 0
    )

    noteScrollFrame = CreateFrame("ScrollFrame", nil, noteFrame)
    noteScrollFrame:SetAllPoints(noteFrame)

    noteContentFrame = CreateFrame("Frame")
    noteContentFrame:SetWidth(sz.width)
    noteContentFrame:SetHeight(sz.height)
    noteScrollFrame:SetScrollChild(noteContentFrame)

    noteText = noteContentFrame:CreateFontString(nil, "OVERLAY")
    noteFrame.noteText = noteText
    AF.SetPoint(noteText, "TOPLEFT", noteContentFrame, 0, 0)
    AF.SetPoint(noteText, "TOPRIGHT", noteContentFrame, 0, 0)
    noteText:SetJustifyH("LEFT")
    noteText:SetJustifyV("TOP")
    noteText:SetWordWrap(true)

    noteFrame:EnableMouseWheel(true)
    noteFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = noteScrollFrame:GetVerticalScroll()
        local max = noteScrollFrame:GetVerticalScrollRange()
        noteScrollFrame:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    if not settings.locked then
        noteResizeButton = AF.CreateResizeButton(noteFrame, 200, 80)
    end

    noteFrame:SetScript("OnSizeChanged", function(self, w, h)
        local s = GetSettings()
        s.size.width = w
        s.size.height = h
        UpdateNoteContentHeight()
    end)

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

---@return boolean
function QRA.Notes.IsEncounterOnlyEnabled()
    return GetSettings().encounterOnly
end

function QRA.Notes.SetEncounterOnly(enabled)
    local settings = GetSettings()
    settings.encounterOnly = enabled

    if enabled then
        QRA.Notes.Hide()
    end
end

function QRA.Notes.ResetPosition()
    local defaultPoint = "CENTER"
    local defaultX = -300
    local defaultY = 0

    UpdateNotePosition(defaultPoint, defaultX, defaultY)
end

---@param encounterId number
---@param bossName string|nil
function QRA.Notes.SetEncounter(encounterId, bossName)
    if not encounterId then
        return
    end

    currentEncounterId = encounterId
    currentBossName = bossName
    RememberSelectedTarget(encounterId, false)

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
    if not QRA.Notes.IsEnabled() and not QRA.Notes.IsEncounterOnlyEnabled() then
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

    if QRA.Notes.UpdatePersonalVisibility then
        QRA.Notes.UpdatePersonalVisibility()
    end
end

---@return boolean
function QRA.Notes.ToggleEnabled()
    local enabled = not QRA.Notes.IsEnabled()
    QRA.Notes.SetEnabled(enabled)
    return enabled
end

function QRA.Notes.SetLocked(locked)
    local settings = GetSettings()
    settings.locked = locked == true

    EnsureNoteFrame()
    if locked and noteResizeButton then
        noteResizeButton:Hide()
    elseif not locked and noteResizeButton then
        noteResizeButton:Show()
    elseif not locked and not noteResizeButton then
        noteResizeButton = AF.CreateResizeButton(noteFrame, 200, 80)
    end

    if QRA.Notes.SetPersonalLocked then
        QRA.Notes.SetPersonalLocked(locked)
    end
end

function QRA.Notes.LockNotes()
    local locked = not GetSettings().locked
    QRA.Notes.SetLocked(locked)
    return locked
end

function QRA.Notes.IsLocked()
    return GetSettings().locked == true
end

---@return string|nil
function QRA.Notes.GetCurrentBossName()
    return currentBossName
end

function QRA.Notes.GetDisplayFontSettings()
    local settings = GetSettings()
    return settings.fontName, settings.fontSize, settings.lineSpacing
end

function QRA.Notes.GetRaidBackgroundOpacity()
    return GetSettings().backgroundAlpha
end

function QRA.Notes.SetRaidBackgroundOpacity(alpha)
    local settings = GetSettings()
    settings.backgroundAlpha = math.max(0, math.min(1, tonumber(alpha) or 0.5))
    ApplyNoteBackgroundOpacity()
end

function QRA.Notes.IsRaidImageBackgroundEnabled()
    return GetSettings().useImageBackground == true
end

function QRA.Notes.SetRaidImageBackgroundEnabled(enabled)
    GetSettings().useImageBackground = enabled == true
    ApplyNoteBackgroundOpacity()
end

function QRA.Notes.GetRaidBackgroundImageName()
    return GetSettings().backgroundImageName or ""
end

function QRA.Notes.SetRaidBackgroundImageName(name)
    GetSettings().backgroundImageName = strtrim(tostring(name or ""))
    ApplyNoteBackgroundOpacity()
end

---@return table[]
local function GetBossItems()
    local items = {
        {
            text = QRA.L["Personal Note"],
            value = PERSONAL_NOTE_KEY,
            bossName = QRA.L["Personal Note"],
        },
    }
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

---@param openPersonal boolean|nil
---@return number|nil encounterId
---@return string|nil bossName
---@return boolean isPersonal
local function GetPreferredConfigTarget(openPersonal)
    if openPersonal then
        return nil, QRA.L["Personal Note"], true
    end

    local lastSelected = GetSettings().lastSelectedNote
    if type(lastSelected) == "table" then
        if lastSelected.type == "personal" then
            return nil, QRA.L["Personal Note"], true
        end

        if lastSelected.type == "boss" and lastSelected.encounterId then
            local encounterId = tonumber(lastSelected.encounterId)
            if encounterId then
                local bossData = QRA.Bosses.GetBossByEncounterId(encounterId)
                if bossData then
                    return encounterId, bossData.name, false
                end
            end
        end
    end

    local initialEncounter = GetInitialEncounterForConfig()
    if initialEncounter then
        local bossData = QRA.Bosses.GetBossByEncounterId(initialEncounter)
        return initialEncounter, bossData and bossData.name or nil, false
    end

    return nil, nil, false
end

local function ShowConfigFrame(openPersonal)
    EnsureNoteFrame()

    local function UpdatePersonalToggleState()
        if not configFrame or not configFrame.personalNoteEnabledCheck then return end

        local personalEnabled = QRA.Notes.IsPersonalEnabled and QRA.Notes.IsPersonalEnabled() or false

        configFrame.personalNoteEnabledCheck:SetChecked(personalEnabled)
    end

    if configFrame then
        configFrame.noteEnabledCheck:SetChecked(QRA.Notes.IsEnabled())
        UpdatePersonalToggleState()
        configFrame.fontDropdown:SetSelectedValue(GetSettings().fontName)
        configFrame.fontSizeSlider:SetValue(GetSettings().fontSize)
        configFrame.lineSpacingSlider:SetValue(GetSettings().lineSpacing)
        if configFrame.raidBackgroundOpacitySlider then
            configFrame.raidBackgroundOpacitySlider:SetValue((GetSettings().backgroundAlpha or 0.5) * 100)
        end
        if configFrame.raidImageBackgroundCheck then
            configFrame.raidImageBackgroundCheck:SetChecked(QRA.Notes.IsRaidImageBackgroundEnabled())
        end
        if configFrame.raidBackgroundImageInput then
            configFrame.raidBackgroundImageInput:SetText(QRA.Notes.GetRaidBackgroundImageName())
        end
        if configFrame.personalBackgroundOpacitySlider and QRA.Notes.GetPersonalBackgroundOpacity then
            configFrame.personalBackgroundOpacitySlider:SetValue((QRA.Notes.GetPersonalBackgroundOpacity() or 0.5) * 100)
        end
        if configFrame.personalImageBackgroundCheck and QRA.Notes.IsPersonalImageBackgroundEnabled then
            configFrame.personalImageBackgroundCheck:SetChecked(QRA.Notes.IsPersonalImageBackgroundEnabled())
        end
        if configFrame.personalBackgroundImageInput and QRA.Notes.GetPersonalBackgroundImageName then
            configFrame.personalBackgroundImageInput:SetText(QRA.Notes.GetPersonalBackgroundImageName())
        end

        if configFrame.LoadEditorForEncounter then
            local encounterId, bossName, isPersonal = GetPreferredConfigTarget(openPersonal)
            if isPersonal or encounterId then
                configFrame.LoadEditorForEncounter(encounterId, bossName, isPersonal)
            end

            if encounterId and not isPersonal then
                QRA.Notes.SetEncounter(encounterId, bossName)
                if QRA.Notes.IsEnabled() then
                    EnsureNoteFrame():Show()
                end
            end
        end

        configFrame:Show()
        return
    end

    ---@class AF_HeaderedFrame
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

    local noteEnabledCheck = AF.CreateCheckButton(content, QRA.L["Enable Note"], function(checked)
        QRA.Notes.SetEnabled(checked)
        UpdatePersonalToggleState()
    end)
    AF.SetPoint(noteEnabledCheck, "TOPLEFT", content, 0, 0)
    noteEnabledCheck:SetChecked(QRA.Notes.IsEnabled())
    configFrame.noteEnabledCheck = noteEnabledCheck

    local personalNoteEnabledCheck = AF.CreateCheckButton(content, QRA.L["Enable Personal Note"], function(checked)
        if QRA.Notes and QRA.Notes.SetPersonalEnabled then
            QRA.Notes.SetPersonalEnabled(checked)
        end
    end)
    AF.SetPoint(personalNoteEnabledCheck, "LEFT", noteEnabledCheck, "RIGHT", 120, 0)
    personalNoteEnabledCheck:SetChecked(QRA.Notes and QRA.Notes.IsPersonalEnabled and QRA.Notes.IsPersonalEnabled() or false)
    configFrame.personalNoteEnabledCheck = personalNoteEnabledCheck
    UpdatePersonalToggleState()

    local lockFramesCheck = AF.CreateCheckButton(content, QRA.L["Lock Frames"], function(checked)
        if QRA.Notes and QRA.Notes.SetLocked then
            QRA.Notes.SetLocked(checked)
        end
    end)
    AF.SetPoint(lockFramesCheck, "LEFT", personalNoteEnabledCheck, "RIGHT", 160, 0)
    lockFramesCheck:SetChecked(GetSettings().locked)
    configFrame.lockFramesCheck = lockFramesCheck

    local encounterOnlyCheck = AF.CreateCheckButton(content, QRA.L["Encounter Only"], function(checked)
        local settings = GetSettings()
        settings.encounterOnly = checked
    end)
    AF.SetPoint(encounterOnlyCheck, "LEFT", lockFramesCheck, "RIGHT", 100, 0)
    encounterOnlyCheck:SetChecked(GetSettings().encounterOnly)

    local unlockBtn = AF.CreateButton(content, QRA.L["Show Movers"], "static", 106, 22)
    AF.SetPoint(unlockBtn, "TOPLEFT", noteEnabledCheck, "BOTTOMLEFT", 0, -8)
    unlockBtn:SetOnClick(function()
        AF.ShowMovers(MOVER_GROUP)
    end)

    local fontDropdown = AF.CreateDropdown(content, 250)
    fontDropdown:SetLabel(QRA.L["Note Font"])
    AF.SetPoint(fontDropdown, "TOPLEFT", unlockBtn, "BOTTOMLEFT", 0, -25)
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

    local raidBackgroundOpacitySlider = AF.CreateSlider(content, QRA.L["Raid Note Background Opacity"], 250, 0, 100, 1)
    AF.SetPoint(raidBackgroundOpacitySlider, "TOPLEFT", lineSpacingSlider, "BOTTOMLEFT", 0, -32)
    raidBackgroundOpacitySlider:SetValue((currentSettings.backgroundAlpha or 0.5) * 100)
    raidBackgroundOpacitySlider:SetAfterValueChanged(function(value)
        QRA.Notes.SetRaidBackgroundOpacity(value / 100)
    end)
    configFrame.raidBackgroundOpacitySlider = raidBackgroundOpacitySlider

    local personalBackgroundOpacitySlider = AF.CreateSlider(content, QRA.L["Personal Note Background Opacity"], 250, 0, 100, 1)
    AF.SetPoint(personalBackgroundOpacitySlider, "LEFT", raidBackgroundOpacitySlider, "RIGHT", 18, 0)
    if QRA.Notes.GetPersonalBackgroundOpacity then
        personalBackgroundOpacitySlider:SetValue((QRA.Notes.GetPersonalBackgroundOpacity() or 0.5) * 100)
    else
        personalBackgroundOpacitySlider:SetValue(50)
    end
    personalBackgroundOpacitySlider:SetAfterValueChanged(function(value)
        if QRA.Notes.SetPersonalBackgroundOpacity then
            QRA.Notes.SetPersonalBackgroundOpacity(value / 100)
        end
    end)
    configFrame.personalBackgroundOpacitySlider = personalBackgroundOpacitySlider

    local raidImageBackgroundCheck = AF.CreateCheckButton(content, QRA.L["Raid Note Image Background"], function(checked)
        QRA.Notes.SetRaidImageBackgroundEnabled(checked)
    end)
    AF.SetPoint(raidImageBackgroundCheck, "TOPLEFT", raidBackgroundOpacitySlider, "BOTTOMLEFT", 0, -18)
    raidImageBackgroundCheck:SetChecked(QRA.Notes.IsRaidImageBackgroundEnabled())
    configFrame.raidImageBackgroundCheck = raidImageBackgroundCheck

    local personalImageBackgroundCheck = AF.CreateCheckButton(content, QRA.L["Personal Note Image Background"], function(checked)
        if QRA.Notes.SetPersonalImageBackgroundEnabled then
            QRA.Notes.SetPersonalImageBackgroundEnabled(checked)
        end
    end)
    AF.SetPoint(personalImageBackgroundCheck, "LEFT", raidImageBackgroundCheck, "RIGHT", 255, 0)
    if QRA.Notes.IsPersonalImageBackgroundEnabled then
        personalImageBackgroundCheck:SetChecked(QRA.Notes.IsPersonalImageBackgroundEnabled())
    else
        personalImageBackgroundCheck:SetChecked(false)
    end
    configFrame.personalImageBackgroundCheck = personalImageBackgroundCheck

    local raidBackgroundImageInput = AF.CreateEditBox(content, QRA.L["Image"], 250, 20)
    AF.SetPoint(raidBackgroundImageInput, "TOPLEFT", raidImageBackgroundCheck, "BOTTOMLEFT", 0, -10)
    raidBackgroundImageInput:SetText(QRA.Notes.GetRaidBackgroundImageName())
    raidBackgroundImageInput:SetOnTextChanged(function(value)
        QRA.Notes.SetRaidBackgroundImageName(value)
    end)
    configFrame.raidBackgroundImageInput = raidBackgroundImageInput

    local personalBackgroundImageInput = AF.CreateEditBox(content, QRA.L["Image"], 250, 20)
    AF.SetPoint(personalBackgroundImageInput, "LEFT", raidBackgroundImageInput, "RIGHT", 18, 0)
    if QRA.Notes.GetPersonalBackgroundImageName then
        personalBackgroundImageInput:SetText(QRA.Notes.GetPersonalBackgroundImageName())
    else
        personalBackgroundImageInput:SetText("")
    end
    personalBackgroundImageInput:SetOnTextChanged(function(value)
        if QRA.Notes.SetPersonalBackgroundImageName then
            QRA.Notes.SetPersonalBackgroundImageName(value)
        end
    end)
    configFrame.personalBackgroundImageInput = personalBackgroundImageInput

    local bossDropdown = AF.CreateCascadingMenuButton(content, 520)
    bossDropdown:SetLabel(QRA.L["Boss"])
    AF.SetPoint(bossDropdown, "TOPLEFT", raidBackgroundImageInput, "BOTTOMLEFT", 0, -25)
    bossDropdown:SetItems(GetBossItems())

    local iconBar = CreateFrame("Frame", nil, content)
    AF.SetSize(iconBar, 520, 22)
    AF.SetPoint(iconBar, "TOPLEFT", bossDropdown, "BOTTOMLEFT", 0, -20)

    local editor = AF.CreateScrollEditBox(content, nil, QRA.L["Boss Note"], 520, 300)
    AF.SetPoint(editor, "TOPLEFT", iconBar, "BOTTOMLEFT", 0, -6)

    if editor.eb then
        editor.eb:HookScript("OnEditFocusGained", function(editBox)
            local cursor = editBox:GetCursorPosition() or 0
            editBox:HighlightText(cursor, cursor)
        end)
    end

    local selectedEncounterId = nil
    local selectedBossName = nil
    local selectedPersonalNote = false
    local suppressAutoSave = false

    local function PersistEditorText(text)
        if selectedPersonalNote then
            if QRA.Notes.SetPersonalRawText then
                QRA.Notes.SetPersonalRawText(text or "")
            end
            if QRA.Notes.RefreshPersonalDisplay then
                QRA.Notes.RefreshPersonalDisplay()
            end
            return
        end

        if not selectedEncounterId then
            return
        end

        SaveNote(selectedEncounterId, text or "")
        QRA.Notes.RefreshNote(selectedEncounterId)
    end

    editor:SetOnTextChanged(function(value)
        if suppressAutoSave then
            return
        end

        PersistEditorText(value)
    end)

    local function LoadEditorForEncounter(encounterId, bossName, isPersonal)
        selectedPersonalNote = isPersonal == true or encounterId == PERSONAL_NOTE_KEY

        if selectedPersonalNote then
            selectedEncounterId = nil
            selectedBossName = QRA.L["Personal Note"]
            bossDropdown:SetText(selectedBossName)
            RememberSelectedTarget(nil, true)
            suppressAutoSave = true
            if QRA.Notes.GetPersonalRawText then
                editor:SetText(QRA.Notes.GetPersonalRawText() or "")
            else
                editor:SetText("")
            end
            editor:SetCursorPosition(0)
            suppressAutoSave = false
            return
        end

        selectedEncounterId = encounterId
        selectedBossName = bossName
        bossDropdown:SetText(bossName or QRA.L["-- Select Boss --"])
        RememberSelectedTarget(encounterId, false)
        suppressAutoSave = true
        editor:SetText(encounterId and GetNote(encounterId) or "")
        editor:SetCursorPosition(0)
        suppressAutoSave = false
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

        suppressAutoSave = true
        editBox:Insert("")
        local textNew = editBox:GetText() or ""
        local cursorNew = editBox:GetCursorPosition() or cursor

        editBox:SetText(text)
        editBox:SetCursorPosition(cursor)
        suppressAutoSave = false

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
            if item.value == PERSONAL_NOTE_KEY then
                LoadEditorForEncounter(nil, item.bossName or item.text, true)
            else
                local bossName = item.bossName or item.text
                QRA.Notes.SetEncounter(item.value, bossName)
                if QRA.Notes.IsEnabled() then
                    EnsureNoteFrame():Show()
                end
            end
        end
    end)

    local initialEncounter, initialBossName, initialPersonal = GetPreferredConfigTarget(openPersonal)
    if initialPersonal then
        LoadEditorForEncounter(nil, initialBossName or QRA.L["Personal Note"], true)
    elseif initialEncounter then
        LoadEditorForEncounter(initialEncounter, initialBossName, false)
        QRA.Notes.SetEncounter(initialEncounter, initialBossName)
        if QRA.Notes.IsEnabled() then
            EnsureNoteFrame():Show()
        end
    end

    local pushBtn = AF.CreateButton(content, QRA.L["Push Notes to Raid"], "softblue", 142, 24)
    AF.SetPoint(pushBtn, "TOPLEFT", editor, "BOTTOMLEFT", 0, -8)
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

---@param openPersonal? boolean
function QRA.Notes.ShowConfig(openPersonal)
    ShowConfigFrame(openPersonal)
end

function QRA.Notes.GetAllRaw()
    return QRA.DB.notes or {}
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

    local lastSelected = GetSettings().lastSelectedNote
    if type(lastSelected) == "table" and lastSelected.type == "boss" and lastSelected.encounterId then
        local encounterId = tonumber(lastSelected.encounterId)
        if encounterId then
            local bossName = nil
            if QRA.Bosses and QRA.Bosses.GetBossByEncounterId then
                local bossData = QRA.Bosses.GetBossByEncounterId(encounterId)
                bossName = bossData and bossData.name or nil
            end
            QRA.Notes.SetEncounter(encounterId, bossName)
        end
    end

    if QRA.Notes.IsEnabled() then
        noteFrame:Show()
    else
        noteFrame:Hide()
    end

    QRA.Debug("Notes: Module Initialized")
end
