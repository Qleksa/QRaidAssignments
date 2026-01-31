---@diagnostic disable: missing-fields
---@class QRA
local QRA = select(2, ...)

--[[
  QRaidAssignments - Bosses Data File
  Contains data about raid bosses and encounters
]]

---@class BossTrigger: Trigger
---@field name string Name of the trigger
---@field type string Type of trigger

---@class BossData
---@field name string Boss name
---@field abbreviation? string Optional abbreviation for the boss
---@field encounterId number Encounter ID of the boss
---@field npcIds? number[] NPC ID of the boss(es)
---@field zoneName string Zone name where the boss is located
---@field triggers? BossTrigger[] Optional triggers for the boss encounter

---@class InstanceData
---@field instanceId number instance ID
---@field tier number Raid tier number (higher = more recent content, e.g., T15 = 15)
---@field bosses BossData[] list of bosses in the instance

---@class Bosses
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
                    npcIds = { 69465 },
                },
                {
                    name = "Horridon",
                    encounterId = 1575,
                    zoneName = "Royal Amphitheater",
                    npcIds = { 68476 },
                },
                {
                    name = "Council of Elders",
                    abbreviation = "Council",
                    encounterId = 1570,
                    zoneName = "Lightning Promenade",
                    npcIds = {
                        69131, -- Frost King Malakk,
                        69132, -- High Priestess Mar'li,
                        69134, -- Kazra'jin,
                        69078, -- Sul the Sandcrawler
                    }
                },
                {
                    name = "Tortos",
                    encounterId = 1565,
                    zoneName = "Lair of Tortos",
                    npcIds = { 67977 },
                },
                {
                    name = "Megaera",
                    encounterId = 1578,
                    zoneName = "Forgotten Depths",
                    npcIds = {
                        70248, -- Arcane Head
                        70212, -- Flaming Head
                        70235, -- Frozen Head
                        70247, -- Venomous Head
                    },
                    triggers = {
                        {
                            name = "Rampage",
                            type = "UNIT_DIED",
                            targetGuid = "boss",
                            counterFormula = "<= 6",
                            activateIn = '6',
                        }
                    }
                },
                {
                    name = "Ji-Kun",
                    encounterId = 1573,
                    zoneName = "Roost of Ji-Kun",
                    npcIds = { 69712 },
                },
                {
                    name = "Durumu the Forgotten",
                    abbreviation = "Durumu",
                    encounterId = 1572,
                    zoneName = "Watcher's Sanctum",
                    npcIds = { 68036 },
                },
                {
                    name = "Primordius",
                    encounterId = 1574,
                    zoneName = "Saurok Creation Pit",
                    npcIds = { 69017 },
                },
                {
                    name = "Dark Animus",
                    encounterId = 1576,
                    zoneName = "Halls of Flesh-Shaping",
                    npcIds = { 69427 },
                },
                {
                    name = "Iron Qon",
                    encounterId = 1559,
                    zoneName = "Grand Courtyard",
                    npcIds = {
                        68078, -- Iron Qon,
                        68081, -- Dam'ren,
                        68080, -- Quet'zal,
                        68079, -- Ro'shak,
                    },
                    triggers = {
                        {
                            name = "Fist Smash",
                            type = "UNIT_SPELLCAST_SUCCEEDED",
                            spellId = 50630,
                            counterFormula = "3",
                            activateIn = "60, 30",
                        }
                    }
                },
                {
                    name = "Twin Empyreans",
                    abbreviation = "Twins",
                    encounterId = 1560,
                    zoneName = "Celestial Enclave",
                    npcIds = {
                        68905, -- Lu'lin
                        68904, -- Suen
                    },
                },
                {
                    name = "Lei Shen",
                    encounterId = 1579,
                    zoneName = "Pinnacle of Storms",
                    npcIds = { 68397 },
                },
                {
                    name = "Ra-den",
                    encounterId = 1581,
                    zoneName = "Hidden Cell",
                    npcIds = { 69473 },
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
--- @return BossData[]|nil List of bosses in the instance or nil if not found
function QRA.Bosses.GetBossesByInstance(instanceName)
    local instanceData = QRA.Bosses.instances[instanceName]
    if instanceData then
        return instanceData.bosses
    end
    return nil
end

--- Get boss data by encounter ID
--- @param encounterId number Encounter ID of the boss
--- @return BossData|nil Boss data or nil if not found
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
--- @return BossData|nil Boss data or nil if not found
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
--- @return BossData|nil Boss data or nil if not found
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

function QRA.Bosses.Initialize()
    QRA.Debug("Bosses module initialized.")
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

--- Get NPC IDs for a boss by encounter ID
--- @param bossName string Encounter ID of the boss
--- @return number[]|nil List of NPC IDs or nil if not found
function QRA.Bosses.GetBossNpcIds(bossName)
    local bossData = QRA.Bosses.GetBossByName(bossName)
    return bossData and bossData.npcIds or nil
end
