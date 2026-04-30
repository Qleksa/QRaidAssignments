--[[
    QRaidAssignments - Personal Note UI
    Separate local personal note display (never shared)
]]

---@class QRA
local QRA = select(2, ...)

---@type AbstractFramework
local AF = _G.AbstractFramework

QRA.Notes = QRA.Notes or {}

local personalNoteFrame = nil
local personalNoteText = nil

local MOVER_GROUP = "QRA Movers"

local function EnsurePersonalSettings()
    QRA.Settings.personalNoteFrame = QRA.Settings.personalNoteFrame or {}
    local settings = QRA.Settings.personalNoteFrame

    settings.position = settings.position or {
        point = "CENTER",
        xOfs = 300,
        yOfs = 0,
    }

    if settings.enabled == nil then
        settings.enabled = false
    end

    return settings
end

local function EnsurePersonalDB()
    QRA.DB.personalNote = QRA.DB.personalNote or {
        text = "",
        timestamp = time(),
        author = UnitName("player"),
    }

    return QRA.DB.personalNote
end

local function UpdatePersonalNotePosition(point, x, y)
    local settings = EnsurePersonalSettings()
    settings.position.point = point
    settings.position.xOfs = x
    settings.position.yOfs = y

    if personalNoteFrame then
        personalNoteFrame:ClearAllPoints()
        AF.SetPoint(personalNoteFrame, point, QRA.UIParent, x, y)
    end
end

function QRA.Notes.GetPersonalRawText()
    local data = EnsurePersonalDB()
    return data.text or ""
end

function QRA.Notes.SetPersonalRawText(text)
    local data = EnsurePersonalDB()
    data.text = text or ""
    data.timestamp = time()
    data.author = UnitName("player")
end

local function GetPersonalDisplayText()
    local raw = QRA.Notes.GetPersonalRawText()
    if QRA.TextFormatter and QRA.TextFormatter.Format then
        return QRA.TextFormatter.Format(raw)
    end

    return raw
end

local function ApplyPersonalNoteText()
    if not personalNoteText then return end
    personalNoteText:SetText(GetPersonalDisplayText())
end

function QRA.Notes.ApplyPersonalNoteFont(fontName, fontSize, lineSpacing)
    if not personalNoteText then return end
    AF.SetFont(personalNoteText, fontName, fontSize, "none", true)
    personalNoteText:SetSpacing(lineSpacing)
end

local function EnsurePersonalNoteFrame()
    if personalNoteFrame then
        return personalNoteFrame
    end

    local settings = EnsurePersonalSettings()

    personalNoteFrame = CreateFrame("Frame", "QRA_PersonalNoteFrame", QRA.UIParent)
    personalNoteFrame:SetSize(460, 280)
    personalNoteFrame:SetFrameStrata("MEDIUM")

    personalNoteFrame:ClearAllPoints()
    AF.SetPoint(
        personalNoteFrame,
        settings.position.point or "CENTER",
        QRA.UIParent,
        settings.position.xOfs or 300,
        settings.position.yOfs or 0
    )

    personalNoteText = personalNoteFrame:CreateFontString(nil, "OVERLAY")
    AF.SetPoint(personalNoteText, "TOPLEFT", personalNoteFrame, 0, 0)
    AF.SetPoint(personalNoteText, "TOPRIGHT", personalNoteFrame, 0, 0)
    AF.SetPoint(personalNoteText, "BOTTOMLEFT", personalNoteFrame, 0, 0)
    AF.SetPoint(personalNoteText, "BOTTOMRIGHT", personalNoteFrame, 0, 0)
    personalNoteText:SetJustifyH("LEFT")
    personalNoteText:SetJustifyV("TOP")
    personalNoteText:SetWordWrap(true)

    local fontName, fontSize, lineSpacing = "Noto_AP", 14, 2
    if QRA.Notes.GetDisplayFontSettings then
        fontName, fontSize, lineSpacing = QRA.Notes.GetDisplayFontSettings()
    end
    QRA.Notes.ApplyPersonalNoteFont(fontName, fontSize, lineSpacing)
    ApplyPersonalNoteText()

    AF.CreateMover(personalNoteFrame, MOVER_GROUP, QRA.L["Personal Note Frame"], UpdatePersonalNotePosition)

    if settings.enabled then
        personalNoteFrame:Show()
    else
        personalNoteFrame:Hide()
    end

    return personalNoteFrame
end

function QRA.Notes.RefreshPersonalDisplay()
    EnsurePersonalNoteFrame()
    ApplyPersonalNoteText()
end

function QRA.Notes.IsPersonalEnabled()
    return EnsurePersonalSettings().enabled == true
end

local function IsMasterNotesEnabled()
    if QRA.Notes and QRA.Notes.IsEnabled then
        return QRA.Notes.IsEnabled()
    end

    return true
end

function QRA.Notes.UpdatePersonalVisibility()
    EnsurePersonalNoteFrame()

    if QRA.Notes.IsPersonalEnabled() and IsMasterNotesEnabled() then
        personalNoteFrame:Show()
        ApplyPersonalNoteText()
    else
        personalNoteFrame:Hide()
    end
end

function QRA.Notes.SetPersonalEnabled(enabled)
    local settings = EnsurePersonalSettings()
    settings.enabled = enabled == true

    QRA.Notes.UpdatePersonalVisibility()
end

function QRA.Notes.TogglePersonalEnabled()
    local enabled = not QRA.Notes.IsPersonalEnabled()
    QRA.Notes.SetPersonalEnabled(enabled)
    return enabled
end

local previousInitialize = QRA.Notes.Initialize
function QRA.Notes.Initialize()
    if previousInitialize then
        previousInitialize()
    end

    EnsurePersonalDB()
    EnsurePersonalSettings()
    EnsurePersonalNoteFrame()

    QRA.Notes.UpdatePersonalVisibility()

    QRA.Debug("Notes: Personal note initialized")
end
