--[[
    QRaidAssignments - Class and Spec Data
    Contains abbreviations and mappings for classes and specializations
    Designed for Mists Classic (Cata+ API)
]]

---@class QRA
local QRA = select(2, ...)
QRA.ClassSpecs = {}

--------------------------------------------------
-- Class Data
-- Keys are class file names (WARRIOR, PALADIN, etc.)
--------------------------------------------------
QRA.ClassSpecs.Classes = {
    ["WARRIOR"] = {
        name = "Warrior",
        abbrev = "WARR",
        color = {0.78, 0.61, 0.43},
        icon = "classicon-warrior",
        specs = {
            [1] = { name = "Arms", abbrev = "ARMS", role = "DPS" },
            [2] = { name = "Fury", abbrev = "FURY", role = "DPS" },
            [3] = { name = "Protection", abbrev = "PWARR", role = "TANK" },
        },
    },
    ["PALADIN"] = {
        name = "Paladin",
        abbrev = "PAL",
        color = {0.96, 0.55, 0.73},
        icon = "classicon-paladin",
        specs = {
            [1] = { name = "Holy", abbrev = "HPAL", role = "HEALER" },
            [2] = { name = "Protection", abbrev = "PPAL", role = "TANK" },
            [3] = { name = "Retribution", abbrev = "RET", role = "DPS" },
        },
    },
    ["HUNTER"] = {
        name = "Hunter",
        abbrev = "HUNT",
        color = {0.67, 0.83, 0.45},
        icon = "classicon-hunter",
        specs = {
            [1] = { name = "Beast Mastery", abbrev = "BM", role = "DPS" },
            [2] = { name = "Marksmanship", abbrev = "MM", role = "DPS" },
            [3] = { name = "Survival", abbrev = "SURV", role = "DPS" },
        },
    },
    ["ROGUE"] = {
        name = "Rogue",
        abbrev = "ROGUE",
        color = {1.00, 0.96, 0.41},
        icon = "classicon-rogue",
        specs = {
            [1] = { name = "Assassination", abbrev = "ASSA", role = "DPS" },
            [2] = { name = "Combat", abbrev = "COMBAT", role = "DPS" },
            [3] = { name = "Subtlety", abbrev = "SUB", role = "DPS" },
        },
    },
    ["PRIEST"] = {
        name = "Priest",
        abbrev = "PRIEST",
        color = {1.00, 1.00, 1.00},
        icon = "classicon-priest",
        specs = {
            [1] = { name = "Discipline", abbrev = "DISC", role = "HEALER" },
            [2] = { name = "Holy", abbrev = "HPRIEST", role = "HEALER" },
            [3] = { name = "Shadow", abbrev = "SPRIEST", role = "DPS" },
        },
    },
    ["DEATHKNIGHT"] = {
        name = "Death Knight",
        abbrev = "DK",
        color = {0.77, 0.12, 0.23},
        icon = "classicon-deathknight",
        specs = {
            [1] = { name = "Blood", abbrev = "BLOOD", role = "TANK" },
            [2] = { name = "Frost", abbrev = "FROSTDK", role = "DPS" },
            [3] = { name = "Unholy", abbrev = "UHDK", role = "DPS" },
        },
    },
    ["SHAMAN"] = {
        name = "Shaman",
        abbrev = "SHAM",
        color = {0.00, 0.44, 0.87},
        icon = "classicon-shaman",
        specs = {
            [1] = { name = "Elemental", abbrev = "ELE", role = "DPS" },
            [2] = { name = "Enhancement", abbrev = "ENHA", role = "DPS" },
            [3] = { name = "Restoration", abbrev = "RSHAM", role = "HEALER" },
        },
    },
    ["MAGE"] = {
        name = "Mage",
        abbrev = "MAGE",
        color = {0.41, 0.80, 0.94},
        icon = "classicon-mage",
        specs = {
            [1] = { name = "Arcane", abbrev = "ARCANE", role = "DPS" },
            [2] = { name = "Fire", abbrev = "FIRE", role = "DPS" },
            [3] = { name = "Frost", abbrev = "FROSTMAGE", role = "DPS" },
        },
    },
    ["WARLOCK"] = {
        name = "Warlock",
        abbrev = "LOCK",
        color = {0.58, 0.51, 0.79},
        icon = "classicon-warlock",
        specs = {
            [1] = { name = "Affliction", abbrev = "AFFLI", role = "DPS" },
            [2] = { name = "Demonology", abbrev = "DEMO", role = "DPS" },
            [3] = { name = "Destruction", abbrev = "DESTRO", role = "DPS" },
        },
    },
    ["MONK"] = {
        name = "Monk",
        abbrev = "MONK",
        color = {0.00, 1.00, 0.59},
        icon = "classicon-monk",
        specs = {
            [1] = { name = "Brewmaster", abbrev = "BRM", role = "TANK" },
            [2] = { name = "Mistweaver", abbrev = "MW", role = "HEALER" },
            [3] = { name = "Windwalker", abbrev = "WW", role = "DPS" },
        },
    },
    ["DRUID"] = {
        name = "Druid",
        abbrev = "DRUID",
        color = {1.00, 0.49, 0.04},
        icon = "classicon-druid",
        specs = {
            [1] = { name = "Balance", abbrev = "BDRUID", role = "DPS" },
            [2] = { name = "Feral", abbrev = "FDRUID", role = "DPS" },
            [3] = { name = "Guardian", abbrev = "GDRUID", role = "TANK" },
            [4] = { name = "Restoration", abbrev = "RDRUID", role = "HEALER" },
        },
    },
}

--------------------------------------------------
-- Role Data
--------------------------------------------------
QRA.ClassSpecs.Roles = {
    ["TANK"] = { name = "Tank", icon = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", coords = {0, 0.26, 0.26, 0.52} },
    ["HEALER"] = { name = "Healer", icon = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", coords = {0.26, 0.52, 0, 0.26} },
    ["DPS"] = { name = "DPS", icon = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", coords = {0.26, 0.52, 0.26, 0.52} },
}

--------------------------------------------------
-- Lookup Tables (built at load time)
--------------------------------------------------
local abbrevToClass = {}      -- "WARR" -> "WARRIOR"
local abbrevToSpec = {}       -- "HPAL" -> { classFile = "PALADIN", specIndex = 1 }

-- Build lookup tables
local function BuildLookupTables()
    for classFile, classData in pairs(QRA.ClassSpecs.Classes) do
        -- Class abbreviation lookup
        abbrevToClass[classData.abbrev] = classFile

        -- Spec abbreviation lookup
        for specIndex, specData in pairs(classData.specs) do
            abbrevToSpec[specData.abbrev] = {
                classFile = classFile,
                specIndex = specIndex,
                role = specData.role,
            }
        end
    end
end

BuildLookupTables()

--------------------------------------------------
-- API Functions
--------------------------------------------------

--- Get class data by class file name
---@param classFile string e.g., "WARRIOR"
---@return table|nil
function QRA.ClassSpecs.GetClass(classFile)
    return QRA.ClassSpecs.Classes[classFile]
end

--- Get class data by abbreviation
---@param abbrev string e.g., "WARR"
---@return table|nil classData
---@return string|nil classFile
function QRA.ClassSpecs.GetClassByAbbrev(abbrev)
    local classFile = abbrevToClass[abbrev:upper()]
    if classFile then
        return QRA.ClassSpecs.Classes[classFile], classFile
    end
    return nil, nil
end

--- Get spec data by abbreviation
---@param abbrev string e.g., "HPAL"
---@return table|nil specData
---@return table|nil classData
---@return string|nil classFile
function QRA.ClassSpecs.GetSpecByAbbrev(abbrev)
    local specInfo = abbrevToSpec[abbrev:upper()]
    if specInfo then
        local classData = QRA.ClassSpecs.Classes[specInfo.classFile]
        local specData = classData.specs[specInfo.specIndex]
        return specData, classData, specInfo.classFile
    end
    return nil, nil, nil
end

--- Check if an abbreviation is a class
---@param abbrev string
---@return boolean
function QRA.ClassSpecs.IsClassAbbrev(abbrev)
    return abbrevToClass[abbrev:upper()] ~= nil
end

--- Check if an abbreviation is a spec
---@param abbrev string
---@return boolean
function QRA.ClassSpecs.IsSpecAbbrev(abbrev)
    return abbrevToSpec[abbrev:upper()] ~= nil
end

--- Check if an abbreviation is a role
---@param abbrev string
---@return boolean
function QRA.ClassSpecs.IsRoleAbbrev(abbrev)
    return QRA.ClassSpecs.Roles[abbrev:upper()] ~= nil
end

--- Get all class abbreviations
---@return table
function QRA.ClassSpecs.GetAllClassAbbrevs()
    local abbrevs = {}
    for classFile, classData in pairs(QRA.ClassSpecs.Classes) do
        table.insert(abbrevs, {
            abbrev = classData.abbrev,
            classFile = classFile,
            name = classData.name,
        })
    end
    table.sort(abbrevs, function(a, b) return a.name < b.name end)
    return abbrevs
end

--- Get all spec abbreviations for a class
---@param classFile string
---@return table
function QRA.ClassSpecs.GetSpecAbbrevs(classFile)
    local classData = QRA.ClassSpecs.Classes[classFile]
    if not classData then return {} end

    local abbrevs = {}
    for specIndex, specData in pairs(classData.specs) do
        table.insert(abbrevs, {
            abbrev = specData.abbrev,
            specIndex = specIndex,
            name = specData.name,
            role = specData.role,
        })
    end
    table.sort(abbrevs, function(a, b) return a.specIndex < b.specIndex end)
    return abbrevs
end

--- Get role for a spec abbreviation
---@param abbrev string
---@return string|nil role "TANK", "HEALER", or "DPS"
function QRA.ClassSpecs.GetRoleForSpec(abbrev)
    local specInfo = abbrevToSpec[abbrev:upper()]
    if specInfo then
        return specInfo.role
    end
    return nil
end

--- Get class color
---@param classFile string
---@return number r
---@return number g
---@return number b
function QRA.ClassSpecs.GetClassColor(classFile)
    local classData = QRA.ClassSpecs.Classes[classFile]
    if classData then
        return unpack(classData.color)
    end
    return 1, 1, 1
end
