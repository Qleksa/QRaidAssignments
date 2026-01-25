--[[
    QRaidAssignments - Dev Mode: Test Mode Core
    Manages test mode state and persistence
]]

---@class QRA
local QRA = select(2, ...)

--@class QRA_DevMode
QRA.DevMode = QRA.DevMode or {}

---@class QRA_DevMode
local DevMode = QRA.DevMode

--------------------------------------------------
-- State
--------------------------------------------------
local isTestModeActive = false
local testEncounterId = nil
local testBossName = nil

--------------------------------------------------
-- Initialization
--------------------------------------------------

--- Initialize DevMode module and load persisted state
function DevMode.Initialize()
    -- Ensure DB structure exists
    if not QRA.DB.devMode then
        QRA.DB.devMode = {
            enabled = false,
            lastBossName = nil,
            lastEncounterId = nil,
            windowPositions = {},
            fakePlayers = DevMode.GetDefaultFakePlayers(),
            eventHistory = {},
            encounterActive = false,
        }
    end

    -- Restore test mode state if it was enabled
    if QRA.DB.devMode.enabled then
        isTestModeActive = true
        testBossName = QRA.DB.devMode.lastBossName
        testEncounterId = QRA.DB.devMode.lastEncounterId
        QRA.Debug("DevMode: Restored test mode state - Boss:", testBossName)
    end

    QRA.Debug("DevMode: Module initialized")
end

--------------------------------------------------
-- Default Fake Players (Class-based)
--------------------------------------------------

--- Get default fake players list
---@return table
function DevMode.GetDefaultFakePlayers()
    return {
        { name = "Warrior1", class = "WARRIOR", guid = "Player-0000-00000001" },
        { name = "Warrior2", class = "WARRIOR", guid = "Player-0000-00000002" },
        { name = "Paladin1", class = "PALADIN", guid = "Player-0000-00000003" },
        { name = "Paladin2", class = "PALADIN", guid = "Player-0000-00000004" },
        { name = "Hunter1", class = "HUNTER", guid = "Player-0000-00000005" },
        { name = "Hunter2", class = "HUNTER", guid = "Player-0000-00000006" },
        { name = "Rogue1", class = "ROGUE", guid = "Player-0000-00000007" },
        { name = "Rogue2", class = "ROGUE", guid = "Player-0000-00000008" },
        { name = "Priest1", class = "PRIEST", guid = "Player-0000-00000009" },
        { name = "Priest2", class = "PRIEST", guid = "Player-0000-00000010" },
        { name = "Shaman1", class = "SHAMAN", guid = "Player-0000-00000011" },
        { name = "Shaman2", class = "SHAMAN", guid = "Player-0000-00000012" },
        { name = "Mage1", class = "MAGE", guid = "Player-0000-00000013" },
        { name = "Mage2", class = "MAGE", guid = "Player-0000-00000014" },
        { name = "Warlock1", class = "WARLOCK", guid = "Player-0000-00000015" },
        { name = "Warlock2", class = "WARLOCK", guid = "Player-0000-00000016" },
        { name = "Druid1", class = "DRUID", guid = "Player-0000-00000017" },
        { name = "Druid2", class = "DRUID", guid = "Player-0000-00000018" },
        { name = "DeathKnight1", class = "DEATHKNIGHT", guid = "Player-0000-00000019" },
        { name = "DeathKnight2", class = "DEATHKNIGHT", guid = "Player-0000-00000020" },
    }
end

--------------------------------------------------
-- Test Mode State Management
--------------------------------------------------

--- Check if test mode is active
---@return boolean
function DevMode.IsActive()
    return isTestModeActive
end

--- Enable test mode
---@param bossName string|nil The boss to test (optional)
---@param encounterId number|nil The encounter ID (optional)
function DevMode.Enable(bossName, encounterId)
    isTestModeActive = true
    testBossName = bossName
    testEncounterId = encounterId

    -- Persist state
    QRA.DB.devMode.enabled = true
    QRA.DB.devMode.lastBossName = bossName
    QRA.DB.devMode.lastEncounterId = encounterId

    QRA.Debug("DevMode: Enabled for boss:", bossName, "encounter:", encounterId)

    -- Notify UI to update
    if DevMode.OnStateChanged then
        DevMode.OnStateChanged(true)
    end
end

--- Disable test mode
function DevMode.Disable()
    -- Stop any active fake encounter first
    if QRA.DevMode.FakeEncounter and QRA.DevMode.FakeEncounter.IsActive() then
        QRA.DevMode.FakeEncounter.Stop()
    end

    isTestModeActive = false
    testBossName = nil
    testEncounterId = nil

    -- Persist state
    QRA.DB.devMode.enabled = false
    QRA.DB.devMode.encounterActive = false

    QRA.Debug("DevMode: Disabled")

    -- Notify UI to update
    if DevMode.OnStateChanged then
        DevMode.OnStateChanged(false)
    end
end

--- Toggle test mode
---@return boolean newState
function DevMode.Toggle()
    if isTestModeActive then
        DevMode.Disable()
    else
        DevMode.Enable()
    end
    return isTestModeActive
end

--- Get current test boss info
---@return string|nil bossName
---@return number|nil encounterId
function DevMode.GetTestBoss()
    return testBossName, testEncounterId
end

--- Set test boss
---@param bossName string
---@param encounterId number|nil
function DevMode.SetTestBoss(bossName, encounterId)
    testBossName = bossName
    testEncounterId = encounterId

    QRA.DB.devMode.lastBossName = bossName
    QRA.DB.devMode.lastEncounterId = encounterId

    QRA.Debug("DevMode: Set test boss to:", bossName, "encounter:", encounterId)
end

--------------------------------------------------
-- Players Management
--------------------------------------------------

--- Get available players (raid roster if in raid, otherwise fake players)
---@return table players
function DevMode.GetAvailablePlayers()
    local players = {}

    -- Check if we're in a raid
    local inRaid = IsInRaid()

    if inRaid then
        -- Use actual raid roster
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, class, _, _, _, _, _, classFileName = GetRaidRosterInfo(i)
            if name then
                table.insert(players, {
                    name = name,
                    class = classFileName or class,
                    guid = UnitGUID("raid" .. i),
                    isReal = true,
                })
            end
        end
    else
        -- Use fake players from DB
        players = QRA.DeepCopy(QRA.DB.devMode.fakePlayers or DevMode.GetDefaultFakePlayers())

        -- Add self at the beginning
        local playerName = UnitName("player")
        local _, playerClass = UnitClass("player")
        table.insert(players, 1, {
            name = playerName,
            class = playerClass,
            guid = UnitGUID("player"),
            isReal = true,
        })
    end

    return players
end

--- Get a player by name
---@param playerName string
---@return table|nil player
function DevMode.GetPlayer(playerName)
    local players = DevMode.GetAvailablePlayers()
    for _, player in ipairs(players) do
        if player.name == playerName then
            return player
        end
    end
    return nil
end

--------------------------------------------------
-- Window Position Management
--------------------------------------------------

--- Save window position
---@param windowName string
---@param point string
---@param relativeTo string
---@param relativePoint string
---@param x number
---@param y number
function DevMode.SaveWindowPosition(windowName, point, relativeTo, relativePoint, x, y)
    QRA.DB.devMode.windowPositions[windowName] = {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

--- Get saved window position
---@param windowName string
---@return table|nil position
function DevMode.GetWindowPosition(windowName)
    return QRA.DB.devMode.windowPositions[windowName]
end

--- Apply saved position to a frame
---@param frame Frame
---@param windowName string
---@return boolean success
function DevMode.ApplyWindowPosition(frame, windowName)
    local pos = DevMode.GetWindowPosition(windowName)
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
        return true
    end
    return false
end

--- Save frame's current position
---@param frame Frame
---@param windowName string
function DevMode.SaveFramePosition(frame, windowName)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    DevMode.SaveWindowPosition(windowName, point, "UIParent", relativePoint or point, x, y)
end
