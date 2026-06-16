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
local personalNoteBackground = nil
local personalNoteText = nil
local personalNoteScrollFrame = nil
local personalNoteContentFrame = nil
local personalNoteResizeButton = nil

local MOVER_GROUP = "QRA Movers"

local PERSONAL_BACKGROUND_IMAGE_PATH = "Interface/AddOns/QRaidAssignments/Media/Images/note_personal.jpg"

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

    settings.size = settings.size or { width = 460, height = 280 }
    settings.locked = settings.locked or false
    settings.backgroundAlpha = tonumber(settings.backgroundAlpha)
    if settings.backgroundAlpha == nil then
        settings.backgroundAlpha = 0.5
    end
    settings.backgroundAlpha = math.max(0, math.min(1, settings.backgroundAlpha))
    settings.backgroundImageEnabled = settings.backgroundImageEnabled or false

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

local function UpdatePersonalNoteContentHeight()
    if not personalNoteContentFrame or not personalNoteText or not personalNoteScrollFrame then return end
    local w = personalNoteScrollFrame:GetWidth()
    personalNoteContentFrame:SetWidth(w)
    personalNoteText:SetWidth(w)
    local th = personalNoteText:GetStringHeight()
    personalNoteContentFrame:SetHeight(math.max(th, personalNoteScrollFrame:GetHeight()))
end

local function ApplyPersonalNoteText()
    if not personalNoteText then return end
    personalNoteText:SetText(GetPersonalDisplayText())
    if personalNoteScrollFrame then personalNoteScrollFrame:SetVerticalScroll(0) end
    UpdatePersonalNoteContentHeight()
end

function QRA.Notes.ApplyPersonalNoteFont(fontName, fontSize, lineSpacing)
    if not personalNoteText then return end
    AF.SetFont(personalNoteText, fontName, fontSize, "none", true)
    personalNoteText:SetSpacing(lineSpacing)
    UpdatePersonalNoteContentHeight()
end

local function ApplyPersonalBackgroundOpacity()
    if not personalNoteBackground then return end

    local settings = EnsurePersonalSettings()
    if settings.backgroundImageEnabled then
        personalNoteBackground:SetAlpha(settings.backgroundAlpha)
    else
        -- ponytail: black only for now; keep it dead simple
        personalNoteBackground:SetColorTexture(0, 0, 0, settings.backgroundAlpha)
    end
end

function QRA.Notes.GetPersonalBackgroundOpacity()
    return EnsurePersonalSettings().backgroundAlpha
end

function QRA.Notes.SetPersonalBackgroundOpacity(alpha)
    local settings = EnsurePersonalSettings()
    settings.backgroundAlpha = math.max(0, math.min(1, tonumber(alpha) or 0.5))
    ApplyPersonalBackgroundOpacity()
end

local function ApplyPersonalBackgroundImage()
    if not personalNoteBackground then return end
    if EnsurePersonalSettings().backgroundImageEnabled then
        personalNoteBackground:SetTexture(PERSONAL_BACKGROUND_IMAGE_PATH)
    end
end

function QRA.Notes.GetPersonalBackgroundImage()
    return EnsurePersonalSettings().backgroundImageEnabled
end

function QRA.Notes.SetPersonalBackgroundImage(enabled)
    local settings = EnsurePersonalSettings()
    settings.backgroundImageEnabled = enabled == true

    if settings.backgroundImageEnabled then
        ApplyPersonalBackgroundImage()
    end
    ApplyPersonalBackgroundOpacity()
end

local function EnsurePersonalNoteFrame()
    if personalNoteFrame then
        return personalNoteFrame
    end

    local settings = EnsurePersonalSettings()
    local sz = settings.size

    personalNoteFrame = CreateFrame("Frame", "QRA_PersonalNoteFrame", QRA.UIParent)
    personalNoteFrame:SetSize(sz.width, sz.height)
    personalNoteFrame:SetFrameStrata("MEDIUM")

    personalNoteBackground = personalNoteFrame:CreateTexture(nil, "BACKGROUND")
    personalNoteBackground:SetAllPoints(personalNoteFrame)
    ApplyPersonalBackgroundImage()
    ApplyPersonalBackgroundOpacity()

    personalNoteFrame:ClearAllPoints()
    AF.SetPoint(
        personalNoteFrame,
        settings.position.point or "CENTER",
        QRA.UIParent,
        settings.position.xOfs or 300,
        settings.position.yOfs or 0
    )

    personalNoteScrollFrame = CreateFrame("ScrollFrame", nil, personalNoteFrame)
    personalNoteScrollFrame:SetAllPoints(personalNoteFrame)

    personalNoteContentFrame = CreateFrame("Frame")
    personalNoteContentFrame:SetWidth(sz.width)
    personalNoteContentFrame:SetHeight(sz.height)
    personalNoteScrollFrame:SetScrollChild(personalNoteContentFrame)

    personalNoteText = personalNoteContentFrame:CreateFontString(nil, "OVERLAY")
    AF.SetPoint(personalNoteText, "TOPLEFT", personalNoteContentFrame, 0, 0)
    AF.SetPoint(personalNoteText, "TOPRIGHT", personalNoteContentFrame, 0, 0)
    personalNoteText:SetJustifyH("LEFT")
    personalNoteText:SetJustifyV("TOP")
    personalNoteText:SetWordWrap(true)

    personalNoteFrame:EnableMouseWheel(true)
    personalNoteFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = personalNoteScrollFrame:GetVerticalScroll()
        local max = personalNoteScrollFrame:GetVerticalScrollRange()
        personalNoteScrollFrame:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)

    if not settings.locked then
        personalNoteResizeButton = AF.CreateResizeButton(personalNoteFrame, 200, 80)
    end

    personalNoteFrame:SetScript("OnSizeChanged", function(self, w, h)
        local s = EnsurePersonalSettings()
        s.size.width = w
        s.size.height = h
        UpdatePersonalNoteContentHeight()
    end)

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

function QRA.Notes.ResetPersonalNotePosition()
    local settings = EnsurePersonalSettings()
    settings.position = {
        point = "CENTER",
        xOfs = 300,
        yOfs = 0,
    }

    if personalNoteFrame then
        personalNoteFrame:ClearAllPoints()
        AF.SetPoint(personalNoteFrame, settings.position.point, QRA.UIParent, settings.position.xOfs, settings.position.yOfs)
    end
end

function QRA.Notes.UpdatePersonalVisibility()
    EnsurePersonalNoteFrame()

    if QRA.Notes.IsPersonalEnabled() then
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

function QRA.Notes.SetPersonalLocked(locked)
    local settings = EnsurePersonalSettings()
    settings.locked = locked == true

    EnsurePersonalNoteFrame()
    if locked and personalNoteResizeButton then
        personalNoteResizeButton:Hide()
    elseif not locked and personalNoteResizeButton then
        personalNoteResizeButton:Show()
    elseif not locked and not personalNoteResizeButton then
        personalNoteResizeButton = AF.CreateResizeButton(personalNoteFrame, 200, 80)
    end
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
