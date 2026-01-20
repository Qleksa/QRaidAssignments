--[[
    QRaidAssignments - Raid Roster Management
    Handles live raid roster and saved roster for planning
    Sorts players by raid group, then alphabetically
]]

---@class QRA
local QRA = QRA
QRA.RaidRoster = {}

--------------------------------------------------
-- State
--------------------------------------------------
local liveRoster = {}      -- Current raid members (refreshed on demand)
local savedRoster = {}     -- Saved roster for planning outside raid

--------------------------------------------------
-- Player Data Structure
--------------------------------------------------
-- Each player entry:
-- {
--     name = "PlayerName",
--     classFile = "WARRIOR",
--     specIndex = 3,         -- nil if unknown
--     specAbbrev = "TWARR",  -- nil if unknown  
--     role = "TANK",         -- From spec or assigned role
--     group = 1,
--     unitId = "raid5",      -- Only for live roster
-- }

--------------------------------------------------
-- Helper Functions
--------------------------------------------------

--- Sort players by group then name
local function SortRoster(roster)
    table.sort(roster, function(a, b)
        if a.group ~= b.group then
            return a.group < b.group
        end
        return a.name < b.name
    end)
end

--- Get player's spec using Cata+ API
---@param unitId string
---@return number|nil specIndex
local function GetUnitSpec(unitId)
    if not unitId then return nil end

    -- For the player
    if UnitIsUnit(unitId, "player") then
        return C_SpecializationInfo.GetSpecialization()
    end

    -- For inspected players - requires cached inspect data
    local guid = UnitGUID(unitId)
    if guid then
        -- Try to get from inspect cache if available
        -- Note: Full inspect requires NotifyInspect() which is async
        -- For now, return nil - spec will be detected when available
        return nil
    end

    return nil
end

--- Get role from unit's assigned role (LFG role)
---@param unitId string
---@return string|nil role "TANK", "HEALER", "DPS", or nil
local function GetUnitRole(unitId)
    local role = UnitGroupRolesAssigned(unitId)
    if role and role ~= "NONE" then
        if role == "DAMAGER" then
            return "DPS"
        end
        return role
    end
    return nil
end

--------------------------------------------------
-- Roster Scanning
--------------------------------------------------

--- Scan and update the live roster
---@return table roster
function QRA.RaidRoster.ScanLiveRoster()
    wipe(liveRoster)

    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then
        -- Solo player
        local name = UnitName("player")
        local _, classFile = UnitClass("player")
        local specIndex = C_SpecializationInfo.GetSpecialization()
        local specAbbrev = nil
        local role = nil

        if specIndex then
            local classData = QRA.ClassSpecs.GetClass(classFile)
            if classData and classData.specs[specIndex] then
                specAbbrev = classData.specs[specIndex].abbrev
                role = classData.specs[specIndex].role
            end
        end

        table.insert(liveRoster, {
            name = name,
            classFile = classFile,
            specIndex = specIndex,
            specAbbrev = specAbbrev,
            role = role or "DPS",
            group = 1,
            unitId = "player",
        })

        return liveRoster
    end

    local isRaid = IsInRaid()
    local prefix = isRaid and "raid" or "party"
    local scanCount = isRaid and numMembers or (numMembers - 1)

    for i = 1, scanCount do
        local unitId = prefix .. i
        local name, rank, subgroup, level, classLoc, classFile, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(i)

        if name then
            -- Remove realm name if present
            name = Ambiguate(name, "short")

            local specIndex = GetUnitSpec(unitId)
            local specAbbrev = nil
            local playerRole = GetUnitRole(unitId)

            if specIndex then
                local classData = QRA.ClassSpecs.GetClass(classFile)
                if classData and classData.specs[specIndex] then
                    specAbbrev = classData.specs[specIndex].abbrev
                    playerRole = playerRole or classData.specs[specIndex].role
                end
            end

            table.insert(liveRoster, {
                name = name,
                classFile = classFile,
                specIndex = specIndex,
                specAbbrev = specAbbrev,
                role = playerRole or "DPS",
                group = subgroup or 1,
                unitId = unitId,
            })
        end
    end

    -- Include player if in party (not raid)
    if not isRaid and numMembers > 0 then
        local name = UnitName("player")
        local _, classFile = UnitClass("player")
        local specIndex = C_SpecializationInfo.GetSpecialization()
        local specAbbrev = nil
        local role = GetUnitRole("player")

        if specIndex then
            local classData = QRA.ClassSpecs.GetClass(classFile)
            if classData and classData.specs[specIndex] then
                specAbbrev = classData.specs[specIndex].abbrev
                role = role or classData.specs[specIndex].role
            end
        end

        table.insert(liveRoster, {
            name = name,
            classFile = classFile,
            specIndex = specIndex,
            specAbbrev = specAbbrev,
            role = role or "DPS",
            group = 1,
            unitId = "player",
        })
    end

    SortRoster(liveRoster)

    QRA.Debug("RaidRoster: Scanned", #liveRoster, "members")
    return liveRoster
end

--------------------------------------------------
-- Roster Access
--------------------------------------------------

--- Get the current live roster (scans if empty)
---@param forceRefresh boolean|nil
---@return table roster
function QRA.RaidRoster.GetLiveRoster(forceRefresh)
    if forceRefresh or #liveRoster == 0 then
        QRA.RaidRoster.ScanLiveRoster()
    end
    return liveRoster
end

--- Get the saved roster
---@return table roster
function QRA.RaidRoster.GetSavedRoster()
    return savedRoster
end

--- Get the active roster (saved if available and not in raid, otherwise live)
---@return table roster
---@return boolean isSaved
function QRA.RaidRoster.GetActiveRoster()
    local numMembers = GetNumGroupMembers()

    -- If in raid/party, always use live roster
    if numMembers > 0 then
        return QRA.RaidRoster.GetLiveRoster(true), false
    end

    -- Not in group - use saved roster if available
    if #savedRoster > 0 then
        return savedRoster, true
    end

    -- Fall back to live (will just be solo player)
    return QRA.RaidRoster.GetLiveRoster(true), false
end

--- Check if we're using saved roster
---@return boolean
function QRA.RaidRoster.IsUsingSavedRoster()
    local numMembers = GetNumGroupMembers()
    return numMembers == 0 and #savedRoster > 0
end

--------------------------------------------------
-- Saved Roster Management
--------------------------------------------------

--- Save current roster for later use
---@param name string|nil Optional name for the saved roster
function QRA.RaidRoster.SaveCurrentRoster(name)
    QRA.RaidRoster.ScanLiveRoster()

    savedRoster = QRA.DeepCopy(liveRoster)

    -- Remove unitId from saved roster (not valid outside raid)
    for _, player in ipairs(savedRoster) do
        player.unitId = nil
    end

    QRA.RaidRoster.SaveToDB()
    QRA.Debug("RaidRoster: Saved roster with", #savedRoster, "members")
end

--- Clear the saved roster
function QRA.RaidRoster.ClearSavedRoster()
    wipe(savedRoster)
    QRA.RaidRoster.SaveToDB()
    QRA.Debug("RaidRoster: Cleared saved roster")
end

--- Manually add a player to saved roster
---@param playerData table
function QRA.RaidRoster.AddToSavedRoster(playerData)
    table.insert(savedRoster, playerData)
    SortRoster(savedRoster)
    QRA.RaidRoster.SaveToDB()
end

--- Remove a player from saved roster by name
---@param playerName string
function QRA.RaidRoster.RemoveFromSavedRoster(playerName)
    for i, player in ipairs(savedRoster) do
        if player.name == playerName then
            table.remove(savedRoster, i)
            QRA.RaidRoster.SaveToDB()
            return
        end
    end
end

--- Update a player's spec in saved roster
---@param playerName string
---@param specAbbrev string
function QRA.RaidRoster.UpdatePlayerSpec(playerName, specAbbrev)
    for _, player in ipairs(savedRoster) do
        if player.name == playerName then
            player.specAbbrev = specAbbrev

            -- Update role based on spec
            local specData = QRA.ClassSpecs.GetSpecByAbbrev(specAbbrev)
            if specData then
                player.role = specData.role
            end

            QRA.RaidRoster.SaveToDB()
            return
        end
    end
end

--------------------------------------------------
-- Query Functions
--------------------------------------------------

--- Get players matching a specific role
---@param role string "TANK", "HEALER", or "DPS"
---@param roster table|nil Optional roster to search (uses active roster if nil)
---@return table players
function QRA.RaidRoster.GetPlayersByRole(role, roster)
    roster = roster or QRA.RaidRoster.GetActiveRoster()
    local players = {}

    for _, player in ipairs(roster) do
        if player.role == role then
            table.insert(players, player)
        end
    end

    return players
end

--- Get players matching a specific class
---@param classAbbrev string e.g., "WARR"
---@param roster table|nil
---@return table players
function QRA.RaidRoster.GetPlayersByClass(classAbbrev, roster)
    roster = roster or QRA.RaidRoster.GetActiveRoster()
    local players = {}

    local _, classFile = QRA.ClassSpecs.GetClassByAbbrev(classAbbrev)
    if not classFile then return players end

    for _, player in ipairs(roster) do
        if player.classFile == classFile then
            table.insert(players, player)
        end
    end

    return players
end

--- Get players matching a specific spec
---@param specAbbrev string e.g., "HPAL"
---@param roster table|nil
---@return table players
function QRA.RaidRoster.GetPlayersBySpec(specAbbrev, roster)
    roster = roster or QRA.RaidRoster.GetActiveRoster()
    local players = {}

    for _, player in ipairs(roster) do
        if player.specAbbrev and player.specAbbrev:upper() == specAbbrev:upper() then
            table.insert(players, player)
        end
    end

    return players
end

--- Get player by name
---@param name string
---@param roster table|nil
---@return table|nil player
function QRA.RaidRoster.GetPlayerByName(name, roster)
    roster = roster or QRA.RaidRoster.GetActiveRoster()

    for _, player in ipairs(roster) do
        if player.name:lower() == name:lower() then
            return player
        end
    end

    return nil
end

--- Get Nth player of a type
---@param typeAbbrev string e.g., "WARR", "HPAL", "TANK"
---@param index number 1-based index
---@param roster table|nil
---@return table|nil player
function QRA.RaidRoster.GetNthPlayer(typeAbbrev, index, roster)
    local players

    if QRA.ClassSpecs.IsRoleAbbrev(typeAbbrev) then
        players = QRA.RaidRoster.GetPlayersByRole(typeAbbrev:upper(), roster)
    elseif QRA.ClassSpecs.IsSpecAbbrev(typeAbbrev) then
        players = QRA.RaidRoster.GetPlayersBySpec(typeAbbrev, roster)
    elseif QRA.ClassSpecs.IsClassAbbrev(typeAbbrev) then
        players = QRA.RaidRoster.GetPlayersByClass(typeAbbrev, roster)
    else
        return nil
    end

    if index <= #players then
        return players[index]
    end

    return nil
end

--- Count players of a type
---@param typeAbbrev string
---@param roster table|nil
---@return number
function QRA.RaidRoster.CountPlayers(typeAbbrev, roster)
    local players

    if QRA.ClassSpecs.IsRoleAbbrev(typeAbbrev) then
        players = QRA.RaidRoster.GetPlayersByRole(typeAbbrev:upper(), roster)
    elseif QRA.ClassSpecs.IsSpecAbbrev(typeAbbrev) then
        players = QRA.RaidRoster.GetPlayersBySpec(typeAbbrev, roster)
    elseif QRA.ClassSpecs.IsClassAbbrev(typeAbbrev) then
        players = QRA.RaidRoster.GetPlayersByClass(typeAbbrev, roster)
    else
        return 0
    end

    return #players
end

--------------------------------------------------
-- Persistence
--------------------------------------------------

function QRA.RaidRoster.SaveToDB()
    if not QRA.DB then return end
    QRA.DB.savedRoster = savedRoster
end

function QRA.RaidRoster.LoadFromDB()
    if not QRA.DB then return end
    if QRA.DB.savedRoster then
        savedRoster = QRA.DB.savedRoster
        QRA.Debug("RaidRoster: Loaded saved roster with", #savedRoster, "members")
    end
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function QRA.RaidRoster.Initialize()
    QRA.RaidRoster.LoadFromDB()
    QRA.Debug("RaidRoster: Module initialized")
end

-- QRA.Debug("RaidRoster: Module loaded")
