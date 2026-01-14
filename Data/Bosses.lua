---@class QRA
local QRA = QRA

--[[
  QRaidAssignments - Bosses Data File
  Contains data about raid bosses and encounters
]]

---@class BossTrigger
---@field type string Type of trigger
---@field target? string Target of the trigger

---@class BossData
---@field name string Boss name
---@field abbreviation? string Optional abbreviation for the boss
---@field encounterId number Encounter ID of the boss
---@field npcId? number NPC ID of the boss
---@field zoneName string Zone name where the boss is located
---@field triggers? table Optional triggers for the boss encounter

---@class InstanceData
---@field instanceId number instance ID
---@field bosses BossData[] list of bosses in the instance

---@class Bosses
---@field instances table<string, InstanceData> List of instances and their bosses
QRA.Bosses = {
    instances = {
        ["Throne of Thunder"] = {
            instanceId = 1098,
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

function QRA.Bosses.GetAllBosses()
    return QRA.Bosses.instances
end

function QRA.Bosses.GetBossesByInstance(instanceName)
    local instanceData = QRA.Bosses.instances[instanceName]
    if instanceData then
        return instanceData.bosses
    end
    return nil
end

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

function QRA.Bosses.GetBossByZoneName(zoneName)
    for instanceName, instanceData in pairs(QRA.Bosses.instances) do
        for _, bossData in ipairs(instanceData.bosses) do
            if bossData.zoneName == zoneName then
                return instanceName, bossData.name, bossData
            end
        end
    end
    return nil, nil, nil
end
