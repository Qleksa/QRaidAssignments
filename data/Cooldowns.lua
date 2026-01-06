local QRA = _G.QRA

--[[
  QRaidAssignments - Cooldowns Data File
  Contains data about raid cooldowns and abilities
]]

QRA.Cooldowns = {
    ["Warrior"] = {
        { name = "Shield Wall", spellId = 871, iconId = 132362 },
        { name = "Last Stand", spellId = 12975, iconId = 132336 },
        { name = "Rallying Cry", spellId = 97462, iconId = 236264 },
    },
    ["Paladin"] = {
        { name = "Divine Shield", spellId = 642 },
        { name = "Guardian of Ancient Kings", spellId = 86659 },
        { name = "Ardent Defender", spellId = 31850 },
    },
    ["Death Knight"] = {
        { name = "Icebound Fortitude", spellId = 48792 },
        { name = "Anti-Magic Shell", spellId = 48707 },
        { name = "Bone Shield", spellId = 49222 },
    },
    ["Druid"] = {
        { name = "Barkskin", spellId = 22812 },
        { name = "Ironbark", spellId = 102342 },
        { name = "Survival Instincts", spellId = 61336 },
    },
    ["Shaman"] = {
        { name = "Astral Shift", spellId = 108271 },
        { name = "Spirit Link Totem", spellId = 98008 },
    },
    ["Monk"] = {
        { name = "Fortifying Brew", spellId = 115203 },
        { name = "Diffuse Magic", spellId = 122470 },
    },
}

function QRA.Cooldowns.GetClassCDs(className)
    return QRA.Cooldowns[className] or {}
end
