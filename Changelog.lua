--[[
    QRaidAssignments - Changelog Window
    Displays changelog on first login after a new major/minor version
]]

---@class QRA
local QRA = QRA

local AF = _G.AbstractFramework

--------------------------------------------------
-- Module
--------------------------------------------------
QRA.Changelog = {}

--------------------------------------------------
-- Constants
--------------------------------------------------
local WINDOW_WIDTH = 600
local WINDOW_HEIGHT = 400

--------------------------------------------------
-- State
--------------------------------------------------
local changelogFrame = nil

--------------------------------------------------
-- Version Parsing
--------------------------------------------------

--- Parse a version string into major, minor, patch components
---@param versionString string Version string like "1.2.3"
---@return number major, number minor, number patch
local function ParseVersion(versionString)
    if not versionString or versionString == "" then
        return 0, 0, 0
    end
    
    -- Handle @project-version@ placeholder (development builds)
    if versionString:find("@") then
        return 999, 999, 999
    end
    
    local major, minor, patch = versionString:match("^(%d+)%.(%d+)%.(%d+)")
    if not major then
        -- Try parsing without patch version
        major, minor = versionString:match("^(%d+)%.(%d+)")
        patch = "0"
    end
    
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
end

--- Check if the current version is a new major or minor version
---@param lastVersion string Last seen version string
---@param currentVersion string Current addon version string
---@return boolean isNewVersion True if major or minor version changed
local function IsNewMajorOrMinorVersion(lastVersion, currentVersion)
    local lastMajor, lastMinor, _ = ParseVersion(lastVersion)
    local currentMajor, currentMinor, _ = ParseVersion(currentVersion)
    
    -- New major or minor version
    return currentMajor > lastMajor or (currentMajor == lastMajor and currentMinor > lastMinor)
end

--------------------------------------------------
-- Changelog Content
--------------------------------------------------

--- Get the changelog text for the current version
---@return string changelog The changelog text
local function GetChangelogText()
    -- This will be populated by the BigWigs packager or manually updated
    -- Format: Plain text with version headers
    local changelog = [[
Version 0.6.0
- Added changelog window that appears on first login after new version
- Improved version tracking in saved variables
- Added setting to hide changelog until next version

Version 0.5.0
- Previous version features...
]]
    
    return changelog
end

--------------------------------------------------
-- UI Creation
--------------------------------------------------

--- Create the changelog window
---@return Frame changelogFrame The created frame
local function CreateChangelogWindow()
    if changelogFrame then
        return changelogFrame
    end
    
    changelogFrame = AF.CreateHeaderedFrame(
        UIParent,
        "QRA_ChangelogWindow",
        QRA.L["What's New in QRaidAssignments"],
        WINDOW_WIDTH,
        WINDOW_HEIGHT
    )
    
    changelogFrame:SetPoint("CENTER")
    changelogFrame:SetFrameStrata("DIALOG")
    
    -- Version header
    local versionText = changelogFrame:CreateFontString(nil, "OVERLAY")
    versionText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    versionText:SetPoint("TOPLEFT", changelogFrame, 15, -35)
    versionText:SetPoint("TOPRIGHT", changelogFrame, -15, -35)
    versionText:SetJustifyH("LEFT")
    versionText:SetText(string.format(QRA.L["Version %s"], QRA.version))
    versionText:SetTextColor(AF.GetColorRGB("accent"))
    
    -- Scrollable changelog content
    local scrollFrame = CreateFrame("ScrollFrame", nil, changelogFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", changelogFrame, -35, 45)
    
    -- Backdrop for scroll area
    local backdrop = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
    backdrop:SetAllPoints(scrollFrame)
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    backdrop:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    backdrop:SetBackdropBorderColor(AF.GetColorRGB("gray"))
    backdrop:SetFrameLevel(scrollFrame:GetFrameLevel() - 1)
    
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(WINDOW_WIDTH - 60, 1) -- Height will be set based on text
    scrollFrame:SetScrollChild(content)
    
    -- Changelog text
    local changelogText = content:CreateFontString(nil, "OVERLAY")
    changelogText:SetFont(STANDARD_TEXT_FONT, 12)
    changelogText:SetPoint("TOPLEFT", content, 10, -10)
    changelogText:SetPoint("TOPRIGHT", content, -10, -10)
    changelogText:SetJustifyH("LEFT")
    changelogText:SetJustifyV("TOP")
    changelogText:SetSpacing(3)
    changelogText:SetNonSpaceWrap(true)
    changelogText:SetTextColor(1, 1, 1, 1)
    
    local changelogContent = GetChangelogText()
    changelogText:SetText(changelogContent)
    
    -- Adjust content height based on text
    local textHeight = changelogText:GetStringHeight()
    content:SetHeight(textHeight + 20)
    
    -- Bottom controls frame
    local bottomFrame = CreateFrame("Frame", nil, changelogFrame)
    bottomFrame:SetPoint("BOTTOMLEFT", changelogFrame, 15, 10)
    bottomFrame:SetPoint("BOTTOMRIGHT", changelogFrame, -15, 10)
    bottomFrame:SetHeight(30)
    
    -- Checkbox: Don't show until next version
    local hideCheckbox = AF.CreateCheckBox(
        bottomFrame,
        QRA.L["Don't show until next version"],
        false
    )
    hideCheckbox:SetPoint("LEFT", bottomFrame, 0, 0)
    
    hideCheckbox:SetOnClick(function(checked)
        if QRA.DB and QRA.DB.settings then
            QRA.DB.settings.hideChangelogUntilNextVersion = checked
            QRA.Debug("Changelog: Hide until next version:", checked)
        end
    end)
    
    -- Close button
    local closeBtn = AF.CreateButton(bottomFrame, QRA.L["Close"], "accent", 80, 28)
    closeBtn:SetPoint("RIGHT", bottomFrame, 0, 0)
    closeBtn:SetOnClick(function()
        changelogFrame:Hide()
    end)
    
    -- Update last seen version when closing
    changelogFrame:SetScript("OnHide", function()
        if QRA.DB and QRA.DB.settings then
            QRA.DB.settings.lastSeenVersion = QRA.version
            QRA.Debug("Changelog: Updated last seen version to", QRA.version)
        end
    end)
    
    return changelogFrame
end

--------------------------------------------------
-- Public API
--------------------------------------------------

--- Show the changelog window
function QRA.Changelog.Show()
    local frame = CreateChangelogWindow()
    if frame then
        frame:Show()
    end
end

--- Hide the changelog window
function QRA.Changelog.Hide()
    if changelogFrame then
        changelogFrame:Hide()
    end
end

--- Check if changelog should be shown and display it if needed
--- Called on PLAYER_LOGIN
function QRA.Changelog.CheckAndShow()
    if not QRA.DB or not QRA.DB.settings then
        QRA.Debug("Changelog: DB not initialized, skipping check")
        return
    end
    
    local lastSeenVersion = QRA.DB.settings.lastSeenVersion or "0.0.0"
    local hideUntilNext = QRA.DB.settings.hideChangelogUntilNextVersion or false
    
    QRA.Debug("Changelog: Last seen version:", lastSeenVersion)
    QRA.Debug("Changelog: Current version:", QRA.version)
    QRA.Debug("Changelog: Hide until next:", hideUntilNext)
    
    -- Skip if user chose to hide until next version
    if hideUntilNext and lastSeenVersion == QRA.version then
        QRA.Debug("Changelog: Skipping - user chose to hide")
        return
    end
    
    -- Check if this is a new major or minor version
    if IsNewMajorOrMinorVersion(lastSeenVersion, QRA.version) then
        QRA.Debug("Changelog: New major/minor version detected, showing changelog")
        
        -- Reset the hide flag for new version
        QRA.DB.settings.hideChangelogUntilNextVersion = false
        
        -- Show changelog after a short delay to let UI settle
        QRA.DelayedInvoke(1.5, function()
            QRA.Changelog.Show()
        end)
    else
        QRA.Debug("Changelog: No new major/minor version, not showing")
        -- Update last seen version even if not showing
        QRA.DB.settings.lastSeenVersion = QRA.version
    end
end

--- Initialize the changelog module
function QRA.Changelog.Initialize()
    QRA.Debug("Changelog: Module initialized")
end
