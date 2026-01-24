---@diagnostic disable: missing-fields
---@class QRA
local QRA = select(2, ...)

--[[
  QRaidAssignments - Bosses Data File
  Contains data about raid bosses and encounters
]]

---@class QRA_BossTrigger: Trigger
---@field name string Name of the trigger
---@field type string Type of trigger

---@class QRA_BossData
---@field name string Boss name
---@field abbreviation? string Optional abbreviation for the boss
---@field encounterId number Encounter ID of the boss
---@field npcId? number NPC ID of the boss
---@field zoneName string Zone name where the boss is located
---@field triggers? QRA_BossTrigger[] Optional triggers for the boss encounter

---@class InstanceData
---@field instanceId number instance ID
---@field tier number Raid tier number (higher = more recent content, e.g., T15 = 15)
---@field bosses QRA_BossData[] list of bosses in the instance

---@class QRA_Bosses
---@field instances table<string, InstanceData> List of instances and their bosses
QRA.Bosses = {
    instances = {
        ["Throne of Thunder"] = {
            instanceId = 1098,
            tier = 15,
            bosses = {
                {
                    name = "Jin'rokh the Breaker",
                    abbreviation = "Jin'rokh",
                    encounterId = 1577,
                    zoneName = "Overgrown Statuary",
                },
                {
                    name = "Horridon",
                    encounterId = 1575,
                    zoneName = "Royal Amphitheater",
                },
                {
                    name = "Council of Elders",
                    abbreviation = "Council",
                    encounterId = 1570,
                    zoneName = "Lightning Promenade",
                },
                {
                    name = "Tortos",
                    encounterId = 1565,
                    zoneName = "Lair of Tortos",
                },
                {
                    name = "Megaera",
                    encounterId = 1578,
                    zoneName = "Forgotten Depths",
                    triggers = {
                        {
                            name = "Rampage",
                            type = "UNIT_DIED",
                            targetGuid = "boss",
                            counterFormula = "<= 6",
                            activateIn = 6,
                        }
                    }
                },
                {
                    name = "Ji-Kun",
                    encounterId = 1573,
                    zoneName = "Roost of Ji-Kun",
                },
                {
                    name = "Durumu the Forgotten",
                    abbreviation = "Durumu",
                    encounterId = 1572,
                    zoneName = "Watcher's Sanctum",
                },
                {
                    name = "Primordius",
                    encounterId = 1574,
                    zoneName = "Saurok Creation Pit",
                },
                {
                    name = "Dark Animus",
                    encounterId = 1576,
                    zoneName = "Halls of Flesh-Shaping",
                },
                {
                    name = "Iron Qon",
                    encounterId = 1559,
                    zoneName = "Grand Courtyard",
                },
                {
                    name = "Twin Empyreans",
                    abbreviation = "Twins",
                    encounterId = 1560,
                    zoneName = "Celestial Enclave",
                },
                {
                    name = "Lei Shen",
                    encounterId = 1579,
                    zoneName = "Pinnacle of Storms",
                },
                {
                    name = "Ra-den",
                    encounterId = 1580,
                    zoneName = "Hidden Cell",
                },
            }
        },
    }
}

--- Functions to access boss data
--- @return table<string, InstanceData> List of all instances and their bosses
function QRA.Bosses.GetAllBosses()
    return QRA.Bosses.instances
end

--- Get bosses by instance name
--- @param instanceName string Name of the instance
--- @return QRA_BossData[]|nil List of bosses in the instance or nil if not found
function QRA.Bosses.GetBossesByInstance(instanceName)
    local instanceData = QRA.Bosses.instances[instanceName]
    if instanceData then
        return instanceData.bosses
    end
    return nil
end

--- Get boss data by encounter ID
--- @param encounterId number Encounter ID of the boss
--- @return QRA_BossData|nil Boss data or nil if not found
function QRA.Bosses.GetBossByEncounterId(encounterId)
    for instanceName, instanceData in pairs(QRA.Bosses.instances) do
        for _, bossData in ipairs(instanceData.bosses) do
            if bossData.encounterId == encounterId then
                return bossData
            end
        end
    end
    return nil
end

--- Get boss data by boss name
--- @param bossName string Name of the boss
--- @return QRA_BossData|nil Boss data or nil if not found
function QRA.Bosses.GetBossByName(bossName)
    for instanceName, instanceData in pairs(QRA.Bosses.instances) do
        for _, bossData in ipairs(instanceData.bosses) do
            if bossData.name == bossName then
                return bossData
            end
        end
    end
    return nil
end

--- Get boss data by zone name
--- @param zoneName string Zone name where the boss is located
--- @return QRA_BossData|nil Boss data or nil if not found
function QRA.Bosses.GetBossByZoneName(zoneName)
    for _, instanceData in pairs(QRA.Bosses.instances) do
        for _, bossData in ipairs(instanceData.bosses) do
            if bossData.zoneName == zoneName then
                return bossData
            end
        end
    end
    return nil
end

--- Get all instances sorted by tier (descending, so highest tier first)
--- @return table[] List of {instanceName, instanceData} pairs sorted by tier
function QRA.Bosses.GetInstancesSortedByTier()
    local sorted = {}
    for instanceName, instanceData in pairs(QRA.Bosses.instances) do
        table.insert(sorted, {
            name = instanceName,
            data = instanceData,
        })
    end
    table.sort(sorted, function(a, b)
        return (a.data.tier or 0) > (b.data.tier or 0)
    end)
    return sorted
end

--- Get instance data with name
--- @param instanceName string Name of the instance
--- @return InstanceData|nil Instance data or nil if not found
function QRA.Bosses.GetInstance(instanceName)
    return QRA.Bosses.instances[instanceName]
end

--- Get instance name for a boss
--- @param bossName string Name of the boss
--- @return string|nil Instance name or nil if not found
function QRA.Bosses.GetInstanceNameForBoss(bossName)
    for instanceName, instanceData in pairs(QRA.Bosses.instances) do
        for _, bossData in ipairs(instanceData.bosses) do
            if bossData.name == bossName then
                return instanceName
            end
        end
    end
    return nil
end

function QRA.Bosses.Initialize()

end
