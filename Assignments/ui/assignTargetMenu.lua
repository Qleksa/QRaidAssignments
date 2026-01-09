--[[
    QRaidAssignments - Assign Target Menu UI
    Cascading menu for selecting assignment targets
    Supports: All, Role, Class, Spec, Player
]]

---@class QRA
local QRA = QRA
local AF = _G.AbstractFramework

QRA.AssignTargetMenu = {}

--------------------------------------------------
-- Constants
--------------------------------------------------
local MAX_INDEX_OPTIONS = 5  -- Maximum numbered options (e.g., WARR1 through WARR5)

--------------------------------------------------
-- Menu Building
--------------------------------------------------

--- Build menu items for a specific class
---@param classFile string
---@param onSelect function
---@return table|nil menuItem
local function BuildClassMenuItem(classFile, onSelect)
    local classData = QRA.ClassSpecs.GetClass(classFile)
    if not classData then return nil end

    local children = {}

    -- "Any [Class]" option with numbered sub-options
    local anyClassChildren = {}
    for i = 1, MAX_INDEX_OPTIONS do
        table.insert(anyClassChildren, {
            text = classData.abbrev .. i,
            value = classData.abbrev .. i,
            onClick = function()
                if onSelect then onSelect(classData.abbrev .. i) end
            end,
        })
    end

    table.insert(children, {
        text = "Any " .. classData.name,
        value = classData.abbrev,
        notClickable = true,
        children = anyClassChildren,
    })

    -- Add each spec
    for _, specData in pairs(classData.specs) do
        local specChildren = {}
        for i = 1, MAX_INDEX_OPTIONS do
            table.insert(specChildren, {
                text = specData.abbrev .. i,
                value = specData.abbrev .. i,
                onClick = function()
                    if onSelect then onSelect(specData.abbrev .. i) end
                end,
            })
        end

        table.insert(children, {
            text = specData.name .. " (" .. specData.abbrev .. ")",
            value = specData.abbrev,
            notClickable = true,
            children = specChildren,
        })
    end

    return {
        text = classData.name,
        icon = classData.icon,
        isIconAtlas = true,
        notClickable = true,
        children = children,
    }
end

--- Build menu items for roles
---@param onSelect function
---@return table menuItems
local function BuildRoleMenuItems(onSelect)
    local items = {}

    for roleKey, roleData in pairs(QRA.ClassSpecs.Roles) do
        local children = {}

        -- "All [Role]" option
        table.insert(children, {
            text = "All " .. roleData.name .. "s",
            value = roleKey,
            onClick = function()
                if onSelect then onSelect(roleKey) end
            end,
        })

        -- Numbered options
        for i = 1, MAX_INDEX_OPTIONS do
            table.insert(children, {
                text = roleKey .. i,
                value = roleKey .. i,
                onClick = function()
                    if onSelect then onSelect(roleKey .. i) end
                end,
            })
        end

        table.insert(items, {
            text = roleData.name,
            notClickable = true,
            children = children,
        })
    end

    -- Sort: Tank, Healer, DPS
    table.sort(items, function(a, b)
        local order = { Tank = 1, Healer = 2, DPS = 3 }
        return (order[a.text] or 99) < (order[b.text] or 99)
    end)

    return items
end

--- Build menu items for players (grouped by raid group)
---@param onSelect function
---@return table menuItems
local function BuildPlayerMenuItems(onSelect)
    local roster = QRA.RaidRoster.GetActiveRoster()
    local isSaved = QRA.RaidRoster.IsUsingSavedRoster()

    if #roster == 0 then
        return {
            {
                text = "(No players)",
                notClickable = true,
            }
        }
    end

    -- Group players by raid group
    local groups = {}
    for _, player in ipairs(roster) do
        local groupNum = player.group or 1
        if not groups[groupNum] then
            groups[groupNum] = {}
        end
        table.insert(groups[groupNum], player)
    end

    local items = {}

    -- If small group, show players directly
    if #roster <= 10 then
        for _, player in ipairs(roster) do
            local classData = QRA.ClassSpecs.GetClass(player.classFile)
            local colorR, colorG, colorB = QRA.ClassSpecs.GetClassColor(player.classFile)
            local coloredName = string.format("|cff%02x%02x%02x%s|r", colorR * 255, colorG * 255, colorB * 255, player.name)

            local specText = ""
            if player.specAbbrev then
                specText = " (" .. player.specAbbrev .. ")"
            end

            table.insert(items, {
                text = player.name .. specText,
                value = player.name,
                icon = classData and classData.icon or nil,
                isIconAtlas = classData and true or false,
                onClick = function()
                    if onSelect then onSelect(player.name) end
                end,
            })
        end
    else
        -- Show by group
        for groupNum = 1, 8 do
            if groups[groupNum] and #groups[groupNum] > 0 then
                local groupChildren = {}

                for _, player in ipairs(groups[groupNum]) do
                    local classData = QRA.ClassSpecs.GetClass(player.classFile)
                    local specText = ""
                    if player.specAbbrev then
                        specText = " (" .. player.specAbbrev .. ")"
                    end

                    table.insert(groupChildren, {
                        text = player.name .. specText,
                        value = player.name,
                        icon = classData and classData.icon or nil,
                        isIconAtlas = classData and true or false,
                        onClick = function()
                            if onSelect then onSelect(player.name) end
                        end,
                    })
                end

                table.insert(items, {
                    text = "Group " .. groupNum,
                    notClickable = true,
                    children = groupChildren,
                })
            end
        end
    end

    -- Add indicator if using saved roster
    if isSaved then
        table.insert(items, 1, {
            text = "|cff888888(Saved Roster)|r",
            notClickable = true,
        })
    end

    return items
end

--- Build the complete menu structure
---@param onSelect function Callback when target is selected
---@return table menuItems
function QRA.AssignTargetMenu.BuildMenuItems(onSelect)
    local items = {}

    -- All
    table.insert(items, {
        text = "All",
        value = "ALL",
        icon = "Interface\\ICONS\\Spell_Holy_BlessedRecovery",
        onClick = function()
            if onSelect then onSelect("ALL") end
        end,
    })

    -- Roles submenu
    table.insert(items, {
        text = "By Role",
        notClickable = true,
        children = BuildRoleMenuItems(onSelect),
    })

    -- Classes submenu
    local classItems = {}
    local classOrder = {
        "WARRIOR", "PALADIN", "DEATHKNIGHT", "DRUID",
        "MONK", "PRIEST", "SHAMAN",
        "HUNTER", "ROGUE", "MAGE", "WARLOCK"
    }

    for _, classFile in ipairs(classOrder) do
        local classMenuItem = BuildClassMenuItem(classFile, onSelect)
        if classMenuItem then
            table.insert(classItems, classMenuItem)
        end
    end

    table.insert(items, {
        text = "By Class/Spec",
        notClickable = true,
        children = classItems,
    })

    -- Players submenu
    table.insert(items, {
        text = "Specific Player",
        notClickable = true,
        children = BuildPlayerMenuItems(onSelect),
    })

    return items
end

--------------------------------------------------
-- Widget Creation
--------------------------------------------------

---@class QRA_AssignTargetMenu : AF_CascadingMenuButton
---@field selectedTarget string|nil

--- Create an assign target cascading menu button
---@param parent Frame Parent frame
---@param width number Button width
---@param onSelect function Callback when target is selected (receives targetStr)
---@return QRA_AssignTargetMenu menuButton
function QRA.AssignTargetMenu.CreateMenuButton(parent, width, onSelect)
    ---@class QRA_AssignTargetMenu
    local menu = AF.CreateCascadingMenuButton(parent, width or 150)
    menu:SetLabel(QRA.L["Assign To"] or "Assign To")
    menu:SetText(QRA.L["-- Select Target --"] or "-- Select Target --")

    -- Selected value storage
    menu.selectedTarget = nil

    -- Build and set items
    local function RefreshItems()
        menu:SetItems(QRA.AssignTargetMenu.BuildMenuItems(function(targetStr)
            menu.selectedTarget = targetStr
            menu:SetText(QRA.AssignTarget.GetDisplayText(targetStr, true))
            if onSelect then
                onSelect(targetStr)
            end
        end))
    end

    RefreshItems()

    -- Hook OnMenuSelection to update display
    hooksecurefunc(menu, "OnMenuSelection", function(self, item, path)
        if item.value then
            menu.selectedTarget = item.value
            menu:SetText(QRA.AssignTarget.GetDisplayText(item.value, true))
        end
    end)

    -- Public API
    function menu:GetSelectedTarget()
        return menu.selectedTarget
    end

    function menu:SetSelectedTarget(targetStr)
        menu.selectedTarget = targetStr
        if targetStr and targetStr ~= "" then
            menu:SetText(QRA.AssignTarget.GetDisplayText(targetStr, true))
        else
            menu:SetText(QRA.L["-- Select Target --"] or "-- Select Target --")
        end
    end

    function menu:RefreshPlayers()
        RefreshItems()
    end

    function menu:ClearSelection()
        menu.selectedTarget = nil
        menu:SetText(QRA.L["-- Select Target --"] or "-- Select Target --")
    end

    return menu
end

--- Create a compact assign target dropdown (for existing assignments display)
---@param parent Frame
---@param width number
---@param onSelect function
---@return Frame dropdown
function QRA.AssignTargetMenu.CreateDropdown(parent, width, onSelect)
    -- For simpler cases, use regular dropdown
    local dropdown = AF.CreateDropdown(parent, width or 150)
    dropdown:SetLabel(QRA.L["Assign To"] or "Assign To")

    -- Build simplified items (no deep nesting)
    local items = {
        { text = "All", value = "ALL" },
        { text = "─── Roles ───", notClickable = true },
        { text = "Tank", value = "TANK" },
        { text = "Healer", value = "HEALER" },
        { text = "DPS", value = "DPS" },
    }

    dropdown:SetItems(items)

    if onSelect then
        dropdown:SetOnSelect(onSelect)
    end

    return dropdown
end

--------------------------------------------------
-- Roster Management UI
--------------------------------------------------

--- Show roster save/manage dialog
---@param parent Frame
function QRA.AssignTargetMenu.ShowRosterManager(parent)
    parent = parent or QRA.UIParent

    local form = CreateFrame("Frame", nil, parent)
    AF.SetWidth(form, 300)
    AF.SetHeight(form, 200)

    -- Info text
    local infoText = AF.CreateFontString(form, "", "white")
    AF.SetPoint(infoText, "TOPLEFT", 0, 0)
    AF.SetPoint(infoText, "TOPRIGHT", 0, 0)
    infoText:SetJustifyH("LEFT")

    local function UpdateInfo()
        local roster = QRA.RaidRoster.GetActiveRoster()
        local numMembers = GetNumGroupMembers()

        local text = ""
        if numMembers > 0 then
            text = "Currently in " .. (IsInRaid() and "raid" or "party") .. " with " .. #roster .. " members.\n"
        else
            text = "Not in a group.\n"
        end

        local savedRoster = QRA.RaidRoster.GetSavedRoster()
        if #savedRoster > 0 then
            text = text .. "Saved roster: " .. #savedRoster .. " members"
        else
            text = text .. "No saved roster."
        end

        infoText:SetText(text)
    end

    UpdateInfo()

    -- Save button
    local saveBtn = AF.CreateButton(form, "Save Current Roster", "accent", 140, 26)
    AF.SetPoint(saveBtn, "TOPLEFT", infoText, "BOTTOMLEFT", 0, -20)
    saveBtn:SetOnClick(function()
        QRA.RaidRoster.SaveCurrentRoster()
        UpdateInfo()
        QRA.Print("Roster saved!")
    end)

    -- Clear button
    local clearBtn = AF.CreateButton(form, "Clear Saved", "red", 140, 26)
    AF.SetPoint(clearBtn, "LEFT", saveBtn, "RIGHT", 10, 0)
    clearBtn:SetOnClick(function()
        QRA.RaidRoster.ClearSavedRoster()
        UpdateInfo()
        QRA.Print("Saved roster cleared.")
    end)

    -- Show dialog
    local dialog = AF.GetDialog(parent, AF.WrapTextInColor("Roster Manager", "accent"), 320)
    AF.SetPoint(dialog, "CENTER", parent, 0, 0)
    dialog:SetContent(form, 100)
    dialog:SetToCustom("Close", "", 60)
end
