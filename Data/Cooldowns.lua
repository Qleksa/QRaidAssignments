--[[
  QRaidAssignments - Cooldowns Data File
  Contains data about raid cooldowns and abilities
]]

---@class QRA
local QRA = select(2, ...)

---@class ClassSpell
---@field name string Spell name
---@field id number Spell ID
---@field icon number Spell icon texture ID

---@class ClassSpells
---@field class string Class name
---@field icon number? Class icon texture ID
---@field spells ClassSpell[] List of spells for the class

---@class QRA.Cooldowns
---@field cds ClassSpells[] List of class spells and their cooldowns
QRA.Cooldowns = {
    cds = {
        {
            class = "Warrior",
            spells = {
                { name = "Rallying Cry",        id = 97462,  icon = 463829 },
                { name = "Vigilance",           id = 114030, icon = 236318 },
                { name = "Shield Wall",         id = 871,    icon = 132362 },
                { name = "Last Stand",          id = 12975,  icon = 135871 },
                { name = "Die by the Sword",    id = 118038, icon = 132336 },
                { name = "Skull Banner",        id = 114207, icon = 603532 },
                { name = "Demoralizing Banner", id = 114203, icon = 604449 },
            }
        },
        {
            class = "Paladin",
            spells = {
                { name = "Devotion Aura",             id = 31821,  icon = 135872 },
                { name = "Hand of Sacrifice",         id = 6940,   icon = 135966 },
                { name = "Divine Protection",         id = 498,    icon = 524353 },
                { name = "Light's Hammer",            id = 114158, icon = 613955 },
                { name = "Execution Sentence",        id = 114157, icon = 613954 },
                { name = "Divine Shield",             id = 642,    icon = 524354 },
                { name = "Holy Avenger",              id = 105809, icon = 571555 },
                { name = "Guardian of Ancient Kings", id = 86659,  icon = 135919 },
                { name = "Ardent Defender",           id = 31850,  icon = 135870 },

            }
        },
        {
            class = "Hunter",
            spells = {
                { name = "Deterrence", id = 148467, icon = 132369 },
            }
        },
        {
            class = "Rogue",
            spells = {
                { name = "Smoke Bomb",       id = 76577, icon = 458733 },
                { name = "Cloak of Shadows", id = 31224, icon = 136177 },
                { name = "Evasion",          id = 5277,  icon = 136205 },
            }
        },
        {
            class = "Priest",
            spells = {
                { name = "Pain Suppression",    id = 33206,  icon = 135936 },
                { name = "Power Word: Barrier", id = 62618,  icon = 253400 },
                { name = "Spirit Shell",        id = 109964, icon = 538565 },
                { name = "Guardian Spirit",     id = 47788,  icon = 237542 },
                { name = "Divine Hymn",         id = 64843,  icon = 237540 },
                { name = "Vampiric Embrace",    id = 15290,  icon = 136230 },
            }
        },
        {
            class = "Death Knight",
            spells = {
                { name = "Anti-Magic Zone",     id = 51052,  icon = 237510 },
                { name = "Anti-Magic Shell",    id = 48707,  icon = 136120 },
                { name = "Vampiric Blood",      id = 55233,  icon = 136168 },
                { name = "Gorefiend's Grasp",   id = 108199, icon = 538767 },
                { name = "Might of Ursoc",      id = 113072, icon = 572036 },
                { name = "Icebound Fortitude",  id = 48792,  icon = 237525 },
                { name = 'Empower Rune Weapon', id = 47568,  icon = 135372 },
            }
        },
        {
            class = "Shaman",
            spells = {
                { name = "Ancestral Guidance", id = 108281,  icon = 538564 },
                { name = "Healing Tide Totem", id = 108280, icon = 538569 },
                { name = "Stormlash Totem",    id = 120668, icon = 538575 },
                { name = "Shamanistic Rage",   id = 30823,  icon = 136088 },
                { name = "Astral Shift",       id = 108271, icon = 538565 },
                { name = "Spirit Link Totem",  id = 98008,  icon = 237586 },
                { name = "Bloodlust",          id = 2825,   icon = 136012 },
            }
        },
        {
            class = "Mage",
            spells = {
                { name = "Ice Block",    id = 45438, icon = 135841 },
                { name = "Mirror Image", id = 55342, icon = 135994 },
                { name = "Time Warp",    id = 80353, icon = 458224 },
            }
        },
        {
            class = "Warlock",
            spells = {

            }
        },
        {
            class = "Monk",
            icon = 626002,
            spells = {
                { name = "Revival",       id = 115310, icon = 237573 },
                { name = "Life Cocoon",   id = 116849, icon = 627485 },
                { name = "Dampen Harm",   id = 122278, icon = 620827 },
                { name = "Diffuse Magic", id = 122783, icon = 775460 },
            }
        },
        {
            class = "Druid",
            spells = {
                { name = "Tranquility",        id = 740,    icon = 136107 },
                { name = "Innervate",          id = 29166,  icon = 136048 },
                { name = "Barkskin",           id = 22812,  icon = 136097 },
                { name = "Survival Instincts", id = 61336,  icon = 236169 },
                { name = "Ironbark",           id = 102342, icon = 572025 },
            }
        },
    }
}

-- Get all cooldown data
---@return ClassSpells[]
function QRA.Cooldowns.GetAll()
    return QRA.Cooldowns.cds
end
