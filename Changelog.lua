--[[
    QRaidAssignments - Changelog Window
    Displays changelog on first login after a new major/minor version
]]

---@class QRA
local QRA = select(2, ...)

---@type AbstractFramework
local AF = _G.AbstractFramework

QRA.Changelog = {}

--------------------------------------------------
-- Constants
--------------------------------------------------

local WINDOW_WIDTH = 600
local WINDOW_HEIGHT = 400

-- Development build version numbers
-- Development builds use @project-version@ placeholder which gets replaced during packaging.
-- While in development, we use 999.999.999 to ensure dev builds always appear as "newer"
-- than any released version, preventing false changelog displays during development.
local DEV_VERSION_MAJOR = 999
local DEV_VERSION_MINOR = 999
local DEV_VERSION_PATCH = 999

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
        return DEV_VERSION_MAJOR, DEV_VERSION_MINOR, DEV_VERSION_PATCH
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
    return currentMajor > lastMajor or (currentMajor == lastMajor and currentMinor >= lastMinor)
end

--------------------------------------------------
-- Changelog Content
--------------------------------------------------

-- Changelog data structure
-- Update this before each major/minor release
-- Format: Each entry is { version = "X.Y.Z", changes = { "item1", "item2", ... } }
local CHANGELOG_DATA = {
    {
        version = "1.0.0",
        changes = {
            "First full release"
        }
    },
    {
        version = "0.11.0",
        changes = {
            "Added UNIT_SPELLCAST_SUCCEEDED trigger type",
            "Fixed UNIT_DIED triggers and improve trigger handling",
        }
    },
    {
        version = "0.10.0",
        changes = {
            "Remove old assignment migration code",
            "Add mover for notification frame",
            "Replace AssignTarget cascading menu with text field (#40)",
            "Fix spell input position and allow message and target in assignment editor to be empty",
            "Make notification widget prettier and added better countdown sounds",
            "Clean up AssignTargetInput validation code",
            "Replace AssignTarget menu with text field",
        }
    },
    {
        version = "0.8.0",
        changes = {
            "Bump version to 0.8.0",
            "UI Overhaul (#38)",
        }
    },
    {
        version = "0.7.0",
        changes = {
            "Bump version to 0.7.0",
            "Add changelog window on first login after version update with automated generation (#37)",
            "Fix timer triggers with intervals being removed prematurely (#36)",
            "Fix GetSpecialization call",
            "Add activateIn field to assignments (#35)",
            "Add copilot instructions",
        }
    },
    {
        version = "0.6.0",
        changes = {
            "Added changelog window that appears on first login after new version",
            "Improved version tracking in saved variables",
            "Added setting to hide changelog until next version",
            "Added manual command /qra changelog for testing",
        }
    },
    -- Add previous versions here as releases are made
}

--- Get the changelog text for the current version
---@return string changelog The changelog text
local function GetChangelogText()
    local lines = {}

    for _, entry in ipairs(CHANGELOG_DATA) do
        table.insert(lines, "Version " .. entry.version)
        for _, change in ipairs(entry.changes) do
            table.insert(lines, "- " .. change)
        end
        table.insert(lines, "") -- Blank line between versions
    end

    return table.concat(lines, "\n")
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
        QRA.L["What's New in Q's Raid Assignments"],
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
    versionText:SetText(string.format(QRA.L["Version %s"], tostring(QRA.version or "Unknown")))
    versionText:SetTextColor(AF.GetColorRGB("accent"))

    -- Scrollable changelog content using AF.CreateScrollFrame
    local scrollFrame = AF.CreateScrollFrame(changelogFrame, nil, WINDOW_WIDTH - 50, WINDOW_HEIGHT - 125)
    scrollFrame:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", changelogFrame, -25, 45)

    -- Changelog text using AF.CreateFontString
    local changelogText = AF.CreateFontString(scrollFrame.scrollContent, GetChangelogText(), "white")
    changelogText:SetPoint("TOPLEFT", scrollFrame.scrollContent, 5, -5)
    changelogText:SetPoint("TOPRIGHT", scrollFrame.scrollContent, -5, -5)
    changelogText:SetJustifyH("LEFT")
    changelogText:SetJustifyV("TOP")
    changelogText:SetSpacing(3)
    changelogText:SetNonSpaceWrap(true)

    -- Calculate and set content height
    local textHeight = changelogText:GetStringHeight()
    scrollFrame:SetContentHeight(textHeight + 10)

    -- Bottom controls frame
    local bottomFrame = CreateFrame("Frame", nil, changelogFrame)
    bottomFrame:SetPoint("BOTTOMLEFT", changelogFrame, 15, 10)
    bottomFrame:SetPoint("BOTTOMRIGHT", changelogFrame, -15, 10)
    bottomFrame:SetHeight(30)

    -- Checkbox: Don't show until next version
    local hideCheckbox = AF.CreateCheckButton(
        bottomFrame,
        QRA.L["Don't show until next version"],
        function(checked)
            if QRA.DB and QRA.DB.settings then
                QRA.DB.settings.hideChangelogUntilNextVersion = checked
                QRA.Debug("Changelog: Hide until next version:", checked)
            end
        end
    )
    hideCheckbox:SetPoint("LEFT", bottomFrame, 0, 0)
    hideCheckbox:SetChecked(
        QRA.DB and QRA.DB.settings and QRA.DB.settings.hideChangelogUntilNextVersion or false
    )

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

    -- Ensure we have valid version strings for comparison
    local lastSeenVersion = tostring(QRA.DB.settings.lastSeenVersion or "0.0.0")
    local currentVersion = tostring(QRA.version or "0.0.0")
    local hideChangelogUntilNext = QRA.DB.settings.hideChangelogUntilNextVersion or false


    -- Skip if user chose to hide until next version
    if hideChangelogUntilNext and lastSeenVersion == currentVersion then
        return
    end

    -- Check if this is a new major or minor version
    if IsNewMajorOrMinorVersion(lastSeenVersion, currentVersion) then
        -- Reset the hide flag for new version
        QRA.DB.settings.hideChangelogUntilNextVersion = false

        -- Show changelog after a short delay to let UI settle
        QRA.DelayedInvoke(1.5, function()
            QRA.Changelog.Show()
        end)
    else
        -- Update last seen version even if not showing
        QRA.DB.settings.lastSeenVersion = currentVersion
    end
end

--- Initialize the changelog module
function QRA.Changelog.Initialize()
end
