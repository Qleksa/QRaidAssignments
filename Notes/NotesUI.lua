--[[
    QRaidAssignments - Notes UI
    MRT-like note feature with raid icon and spell formatting
]]

---@class QRA
local QRA = select(2, ...)

---@type AbstractFramework
local AF = _G.AbstractFramework

QRA.Notes = {}

local noteFrame = nil
local currentEncounterId = nil
local MOVER_GROUP = "QRA Movers"

---@class NoteFrame
---@field editBox Frame|nil
---@field displayText FontString|nil
---@field saveButton Frame|nil
---@field sendButton Frame|nil
---@field scrollFrame ScrollFrame|nil
---@field content Frame|nil

--- Update note frame position from saved settings
local function UpdateNotePosition(point, x, y)
    if not QRA.Settings.noteFrame then
        QRA.Settings.noteFrame = { position = {} }
    end
    QRA.Settings.noteFrame.position.point = point
    QRA.Settings.noteFrame.position.xOfs = x
    QRA.Settings.noteFrame.position.yOfs = y

    if noteFrame then
        noteFrame:ClearAllPoints()
        AF.SetPoint(noteFrame, point, QRA.UIParent, x, y)
    end
end

--- Check if player can edit notes (raid leader or assistant, or DevMode)
---@return boolean
local function CanEditNotes()
    -- Allow editing in DevMode for testing
    if QRA.DevMode and QRA.DevMode.IsActive and QRA.DevMode.IsActive() then
        return true
    end

    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

--- Save note to database
---@param encounterId number
---@param text string
local function SaveNote(encounterId, text)
    if not QRA.DB.notes then
        QRA.DB.notes = {}
    end

    QRA.DB.notes[encounterId] = {
        text = text,
        timestamp = time(),
        author = UnitName("player"),
    }

    QRA.Debug("Note saved for encounter", encounterId)
end

--- Get note for encounter
---@param encounterId number
---@return string|nil
local function GetNote(encounterId)
    if QRA.DB.notes and QRA.DB.notes[encounterId] then
        return QRA.DB.notes[encounterId].text
    end
    return nil
end

--- Refresh note display for the current encounter
---@param encounterId number
function QRA.Notes.RefreshNote(encounterId)
    if not noteFrame or not noteFrame:IsShown() or currentEncounterId ~= encounterId then
        return
    end

    local noteText = GetNote(encounterId) or ""
    local canEdit = CanEditNotes()

    if canEdit and noteFrame.editBox then
        -- Update editbox if changed externally
        local currentText = noteFrame.editBox:GetText() or ""
        if currentText ~= noteText then
            noteFrame.editBox:SetText(noteText)
        end
    elseif noteFrame.displayText then
        -- Update display text
        local formatted = QRA.TextFormatter.Format(noteText)
        noteFrame.displayText:SetText(formatted or "")
    end
end

--- Create the note frame
local function CreateNoteFrame()
    if noteFrame then
        return noteFrame
    end

    -- noteFrame = CreateFrame("Frame", "QRA_NoteFrame", QRA.UIParent)
    -- noteFrame:SetSize(200, 100)
    -- noteFrame:EnableMouse(true)
    -- noteFrame:SetMovable(true)

    noteFrame = AF.CreateBorderedFrame(QRA.UIParent, "QRA_NoteFrame", 200, 300)
    noteFrame.SetTitle = function(self, title)
        self:SetLabel(title)
    end

    -- Apply saved position
    local pos = QRA.Settings.noteFrame.position
    noteFrame:ClearAllPoints()
    AF.SetPoint(noteFrame, pos.point or "CENTER", QRA.UIParent, pos.xOfs or -300, pos.yOfs or 0)
    noteFrame:SetFrameStrata("MEDIUM")
    noteFrame:Hide()

    -- Content area
    local content = CreateFrame("Frame", nil, noteFrame)
    AF.SetPoint(content, "TOPLEFT", noteFrame, 10, -35)
    AF.SetPoint(content, "BOTTOMRIGHT", noteFrame, -10, 40)
    noteFrame.content = content

    -- Create scroll frame for read-only display
    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    AF.SetPoint(scrollFrame, "TOPLEFT", content, 0, 0)
    AF.SetPoint(scrollFrame, "BOTTOMRIGHT", content, -25, 0)
    noteFrame.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(350, 1000)
    scrollFrame:SetScrollChild(scrollChild)

    -- Display text (read-only mode)
    local displayText = AF.CreateFontString(scrollChild, "", "white")
    AF.SetPoint(displayText, "TOPLEFT", scrollChild, 5, -5)
    AF.SetPoint(displayText, "TOPRIGHT", scrollChild, -5, -5)
    displayText:SetJustifyH("LEFT")
    displayText:SetJustifyV("TOP")
    displayText:SetWordWrap(true)
    noteFrame.displayText = displayText

    -- Edit box (edit mode)
    local editBox = AF.CreateEditBox(content, "", 360, 200, "multiline")
    AF.SetPoint(editBox, "TOPLEFT", content, 0, 0)
    AF.SetPoint(editBox, "BOTTOMRIGHT", content, 0, 35)
    editBox:Hide()
    noteFrame.editBox = editBox

    -- Save button
    local saveButton = AF.CreateButton(noteFrame, "Save", "static", 70, 26)
    AF.SetPoint(saveButton, "BOTTOMLEFT", noteFrame, 10, 8)
    saveButton:SetOnClick(function()
        if currentEncounterId and noteFrame.editBox then
            local text = noteFrame.editBox:GetText()
            SaveNote(currentEncounterId, text)
            QRA.Print("Note saved.")
        end
    end)
    saveButton:Hide()
    noteFrame.saveButton = saveButton

    -- Send button
    local sendButton = AF.CreateButton(noteFrame, "Send to Raid", "static", 100, 26)
    AF.SetPoint(sendButton, "LEFT", saveButton, "RIGHT", 8, 0)
    sendButton:SetOnClick(function()
        if currentEncounterId and noteFrame.editBox then
            local text = noteFrame.editBox:GetText()
            SaveNote(currentEncounterId, text)
            QRA.Comm.SendNote(currentEncounterId, text)
        end
    end)
    sendButton:Hide()
    noteFrame.sendButton = sendButton

    -- Close button
    local closeButton = AF.CreateButton(noteFrame, "Close", "gray", 70, 26)
    AF.SetPoint(closeButton, "BOTTOMRIGHT", noteFrame, -10, 8)
    closeButton:SetOnClick(function()
        noteFrame:Hide()
    end)

    -- Add to UISpecialFrames for ESC key handling
    table.insert(UISpecialFrames, noteFrame:GetName())

    -- Create mover
    AF.CreateMover(noteFrame, MOVER_GROUP, "Note Frame", UpdateNotePosition)

    return noteFrame
end

--- Show note for a specific encounter
---@param encounterId number
---@param bossName? string Optional boss name for title
function QRA.Notes.ShowForEncounter(encounterId, bossName)
    QRA.Debug("Notes: ShowForEncounter called for", encounterId, bossName)

    if not noteFrame then
        CreateNoteFrame()
    end

    currentEncounterId = encounterId
    local noteText = GetNote(encounterId) or ""
    local canEdit = CanEditNotes()

    QRA.Debug("Notes: canEdit =", canEdit, "noteText length =", #noteText)

    -- Update title
    local title = bossName and ("Raid Notes - " .. bossName) or "Raid Notes"
    noteFrame:SetTitle(title)

    if canEdit then
        -- Edit mode
        noteFrame.scrollFrame:Hide()
        noteFrame.editBox:Show()
        noteFrame.editBox:SetText(noteText)
        noteFrame.editBox:SetCursorPosition(0)
        noteFrame.saveButton:Show()
        noteFrame.sendButton:Show()
    else
        -- Read-only mode
        noteFrame.editBox:Hide()
        noteFrame.saveButton:Hide()
        noteFrame.sendButton:Hide()
        noteFrame.scrollFrame:Show()

        local formatted = QRA.TextFormatter.Format(noteText)
        noteFrame.displayText:SetText(formatted or "")
    end

    noteFrame:Show()
    QRA.Debug("Notes: Frame shown, isVisible =", noteFrame:IsShown())
end

--- Hide note frame
function QRA.Notes.Hide()
    if noteFrame then
        noteFrame:Hide()
        currentEncounterId = nil
    end
end

--- Check if note frame is visible
---@return boolean
function QRA.Notes.IsVisible()
    return noteFrame ~= nil and noteFrame:IsShown()
end

--- Get current encounter ID being displayed
---@return number|nil
function QRA.Notes.GetCurrentEncounter()
    return currentEncounterId
end

--- Initialize notes module
function QRA.Notes.Initialize()
    QRA.Debug("Notes: Module Initialized")
end
