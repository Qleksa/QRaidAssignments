--[[
    QRaidAssignments - Custom Widgets
    Reusable UI widget definitions built on AbstractFramework
]]

---@class QRA
local QRA = select(2, ...)

---@class QRA_Widgets | QRA_Module
QRA.Widgets = {}

---@type AbstractFramework
local AF = _G.AbstractFramework

--------------------------------------------------
-- Widget Colors
--------------------------------------------------
QRA.Widgets.Colors = {
    triggerType = {
        SPELL_CAST_SUCCESS = "brightgreen",
        SPELL_CAST_START = "yellow",
        SPELL_AURA_APPLIED = "lime",
        SPELL_AURA_REMOVED = "orange",
        TIMER = "skyblue",
        UNIT_DIED = "red",
        UNIT_HEALTH = "purple",
        UNIT_SPELLCAST_SUCCEEDED = "brightgreen",
    },
}

--------------------------------------------------
-- Trigger Type Selector
--------------------------------------------------

--- Create a dropdown for selecting trigger types
---@param parent Frame Parent frame
---@param width number Dropdown width
---@param onSelect? function Callback when selection changes
---@return AF_Dropdown dropdown
function QRA.Widgets.CreateTriggerTypeDropdown(parent, width, onSelect)
    local dropdown = AF.CreateDropdown(parent, width or 150)
    dropdown:SetLabel(QRA.L["Trigger Type"])

    local items = {}
    for _, typeName in pairs(QRA.Triggers.Types) do
        table.insert(items, {
            text = typeName.name,
            value = typeName.event,
        })
    end

    -- Sort alphabetically
    table.sort(items, function(a, b)
        return a.text < b.text
    end)

    dropdown:SetItems(items)

    if onSelect then
        dropdown:SetOnSelect(function(value)
            onSelect(value)
        end)
    end

    return dropdown
end

--------------------------------------------------
-- Spell Input Widget
--------------------------------------------------

local function GetAllSpells(onClick)
    local spells = {}
    for _, cds in ipairs(QRA.Cooldowns.GetAll()) do
        local className = cds.class
        spells[className] = {
            text = className,
            icon =  cds.icon or ("classicon-" .. className:upper():gsub(" ", "")),
            isIconAtlas = true,
            notClickable = true,
            children = #cds.spells > 0 and {} or nil,
        }
        for _, spell in ipairs(cds.spells) do
            table.insert(spells[className].children, {
                text = spell.name,
                icon = spell.icon,
                iconBorderColor = "black",
                onClick = onClick and function()
                    onClick(spell)
                end or nil,
            })
        end
    end

    return spells
end

-- TODO: Refactor to create a editBox that when clicked opens the menu
-- so we dont have two separate inputs for spell selection
local function CreateSpellMenu(parent, width, onClick)
    local spellMenu = AF.CreateCascadingMenuButton(parent, width - 46)
    spellMenu:SetLabel(QRA.L["Select spell"])
    spellMenu:SetItems(GetAllSpells(onClick))

    return spellMenu
end

---@class QRA_SpellInput : Frame
---@field spellMenu AF_CascadingMenuButton
---@field editBox AF_EditBox
---@field icon Texture
---@field SetSpell fun(self: QRA_SpellInput, spellId: number|nil, spellName: string|nil)
---@field GetSpell fun(self: QRA_SpellInput): table
---@field SetCursorPosition fun(self: QRA_SpellInput, position: number)
---@field SetEnabled fun(self: QRA_SpellInput, enabled: boolean)
---@field Clear fun(self: QRA_SpellInput)

--- Create a spell input field with spell icon preview
---@param parent Frame Parent frame
---@param label string|nil Label text
---@param width number Field width
---@param showSpellMenu? boolean Whether to show spell menu button, default yes
---@param onConfirm? function Callback when spell is confirmed
---@return QRA_SpellInput frame
function QRA.Widgets.CreateSpellInput(parent, label, width, showSpellMenu, onConfirm)
    local width = width or 200
    local showSpellMenu = showSpellMenu ~= false
    local container = CreateFrame("Frame", nil, parent)
    AF.SetWidth(container, width)
    AF.SetHeight(container, 40)

    local spellData = {
        spellId = nil,
        spellName = nil,
        spellIcon = 134400,  -- Default question mark icon
    }

    -- Spell icon
    local icon = container:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    AF.SetPoint(icon, "LEFT", 0, 0)
    icon:SetTexture(spellData.spellIcon)  -- Default question mark icon
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Edit box for spell ID or name
    local editBox = AF.CreateEditBox(container, label or QRA.L["Spell ID"], width - 46, 20)
    AF.SetPoint(editBox, "LEFT", icon, "RIGHT", 10, -8)

    -- Update icon when valid spell entered
    local function UpdateSpellIcon(text)
        local spellId = tonumber(text)

        local spellInfo = C_Spell.GetSpellInfo(spellId or text)

        if spellInfo then
            spellData.spellId = spellInfo.spellID
            spellData.spellName = spellInfo.name
            spellData.spellIcon = spellInfo.originalIconID
        end

        if spellData.spellIcon then
            icon:SetTexture(spellData.spellIcon)
            return true, spellId or spellData.spellName
        else
            icon:SetTexture(134400)
            return false, nil
        end

    end

    editBox:SetOnTextChanged(function(text)
        UpdateSpellIcon(text)
    end)

    local spellMenu = CreateSpellMenu(container, width, function (spell)
        spellData.spellId = spell.id
        spellData.spellName = spell.name
        spellData.spellIcon = spell.icon

        icon:SetTexture(spell.icon)
        editBox:SetText(tostring(spell.id))

        if onConfirm then
            onConfirm(spell.id)
        end
    end)
    AF.SetPoint(spellMenu, "LEFT", icon, "RIGHT", 10, 11)
    if showSpellMenu then
        spellMenu:Show()
    else
        spellMenu:Hide()
        AF.SetPoint(editBox, "LEFT", icon, "RIGHT", 10, 0)
    end

    -- Public API
    container.editBox = editBox
    container.icon = icon
    container.spellMenu = spellMenu

    function container:SetSpell(spellId, spellName)
        editBox:SetText(tostring(spellId or ""))
        spellMenu:SetText(tostring(spellName or ""))
        UpdateSpellIcon(tostring(spellId or ""))
    end

    function container:GetSpell()
        return spellData
    end

    function container:SetCursorPosition(position)
        editBox:SetCursorPosition(position)
    end

    function container:SetEnabled(enabled)
        editBox:SetEnabled(enabled)
        spellMenu:SetEnabled(enabled)
    end

    function container:Clear()
        editBox:SetText("")
        icon:SetTexture(134400)
    end

    return container
end

--------------------------------------------------
-- Occurrence Selector
--------------------------------------------------

---@class QRA_CounterInput : AF_EditBox
---@field GetValue fun(self: QRA_CounterInput): string|nil
---@field SetValue fun(self: QRA_CounterInput, value: string|nil)

--- Create an counter formula input box
---@param parent Frame Parent frame
---@param label string|nil Label text
---@param width number Field width
---@return QRA_CounterInput container
function QRA.Widgets.CreateCounterInput(parent, label, width)
    ---@class QRA_CounterInput : AF_EditBox
    local counterEB = AF.CreateEditBox(parent, label or QRA.L["Counter"], width or 150, 20)
    counterEB:SetText("*")

    -- Force initial validation since SetText doesn't trigger OnTextChanged
    local initialText = counterEB:GetText()
    local isValid, errorMsg = QRA.CounterFormula.Validate(initialText)
    -- QRA.Debug("Counter Input: Initial validation result:", isValid, errorMsg)
    if not isValid then
        counterEB:SetBackdropBorderColor(AF.GetColorRGB("red"))
    else
        counterEB:SetBackdropBorderColor(AF.GetColorRGB("gray"))
    end

    counterEB:SetOnTextChanged(function(text)
        -- QRA.Debug("Counter Input: Text changed to", text)

        local ok, err = QRA.CounterFormula.Validate(text)
        QRA.Debug("Counter Input: Validation result:", ok, err)
        counterEB:SetText(text)
        -- counterEB:SetBackdropBorderColor(ok and {1, 0, 0, 1} or AF.GetColorRGB("red"))
    end)

    AF.SetTooltip(counterEB, "TOPLEFT", 0, 2, unpack(QRA.CounterFormula.GetTips()))

    -- Public API
    function counterEB:GetValue()
        return counterEB:GetText() == "" and nil or counterEB:GetText()
    end

    function counterEB:SetValue(value)
        -- QRA.Debug("Counter Input: Setting value to", value)
        local textValue = tostring(value or "")
        counterEB:SetText(textValue)
        -- QRA.Debug("Counter Input: Text after SetValue:", counterEB:GetText())
        -- Manually trigger validation since SetText doesn't call the OnTextChanged callback
        -- local ok, err = QRA.CounterFormula.Validate(textValue)
        -- QRA.Debug("Counter Input: Validation result:", ok, err)
        -- counterEB:SetBackdropBorderColor(ok and AF.GetColorRGB("gray") or AF.GetColorRGB("red"))
    end

    return counterEB
end

--------------------------------------------------
-- Assign Target Input
--------------------------------------------------

---@class QRA_AssignTargetInput : AF_EditBox
---@field GetValue fun(self: QRA_AssignTargetInput): string|nil
---@field SetValue fun(self: QRA_AssignTargetInput, value: string|nil)

--- Create an assign target input box
---@param parent Frame Parent frame
---@param label string|nil Label text
---@param width number Field width
---@return QRA_AssignTargetInput editBox
function QRA.Widgets.CreateAssignTargetInput(parent, label, width)
    ---@class QRA_AssignTargetInput : AF_EditBox
    local editBox = AF.CreateEditBox(parent, label or QRA.L["Assign To"], width or 150, 20)
    editBox:SetText("ALL")

    -- Force initial validation since SetText doesn't trigger OnTextChanged
    local initialText = editBox:GetText()
    local isValid, errorMsg = QRA.AssignTarget.Validate(initialText)
    if not isValid then
        editBox:SetBackdropBorderColor(AF.GetColorRGB("red"))
    else
        editBox:SetBackdropBorderColor(AF.GetColorRGB("gray"))
    end

    editBox:SetOnTextChanged(function(text)
        local ok, err = QRA.AssignTarget.Validate(text)
        QRA.Debug("Assign Target Input: Validation result:", ok, err)
    end)

    AF.SetTooltip(editBox, "TOPLEFT", 0, 2, unpack(QRA.AssignTarget.GetTips()))

    -- Public API
    function editBox:GetValue()
        return editBox:GetText() == "" and nil or editBox:GetText()
    end

    function editBox:SetValue(value)
        local textValue = tostring(value or "ALL")
        editBox:SetText(textValue)
    end

    return editBox
end

--------------------------------------------------
-- Activate In Input
--------------------------------------------------

---@class QRA_ActivateInInput : AF_EditBox
---@field GetValue fun(self: QRA_ActivateInInput): number|nil
---@field SetValue fun(self: QRA_ActivateInInput, value: number|nil)

--- Create an activateIn input field (delay trigger or assignment activation)
---@param parent Frame Parent frame
---@param label string|nil Label text
---@param width number Field width
---@return QRA_ActivateInInput editBox
function QRA.Widgets.CreateActivateInInput(parent, label, width)
    ---@class QRA_ActivateInInput : AF_EditBox
    local editBox = AF.CreateEditBox(parent, label or QRA.L["Activate In (seconds)"], width or 200, 20, "number")

    -- Tooltip
    AF.SetTooltip(editBox, "TOPLEFT", 0, 2,
        QRA.L["Activate In (seconds)"],
        "Delay the activation after the event fires",
        "Example: 3 means activate 3 seconds after the event",
        "Leave empty for immediate activation")

    -- Helper function to validate activateIn value
    local function IsValidActivateInValue(value)
        return value and value >= 0
    end

    -- Public API
    function editBox:GetValue()
        local text = editBox:GetText()
        if text == "" or text == nil then
            return nil
        end
        local value = tonumber(text)
        if IsValidActivateInValue(value) then
            return value
        end
        return nil
    end

    function editBox:SetValue(value)
        if IsValidActivateInValue(value) then
            editBox:SetText(tostring(value))
        else
            editBox:SetText("")
        end
    end

    return editBox
end

--------------------------------------------------
-- HP Thresholds Input
--------------------------------------------------

---@class QRA_HPThresholdsInput : AF_EditBox
---@field IsValid fun(self: QRA_HPThresholdsInput): boolean

--- Create an HP thresholds input field with validation
---@param parent Frame Parent frame
---@param label string|nil Label text
---@param width number Field width
---@return QRA_HPThresholdsInput editBox
function QRA.Widgets.CreateHPThresholdsInput(parent, label, width)
    ---@class QRA_HPThresholdsInput : AF_EditBox
    local editBox = AF.CreateEditBox(parent, label or QRA.L["HP Thresholds (%)"], width or 200, 20)

    -- Tooltip
    AF.SetTooltip(editBox, "TOPLEFT", 0, 2,
        QRA.L["HP Thresholds (%)"],
        "Enter HP percentages separated by commas",
        "Example: 25, 50, 75",
        "Values must be integers between 1 and 100")

    -- Validation state
    local isValid = false

    -- Validate input
    local function Validate(text)
        if not text or text == "" then
            return false
        end

        -- Check for valid format: integers 1-100, comma-separated
        for threshold in string.gmatch(text, "[^,]+") do
            local trimmed = strtrim(threshold)
            local num = tonumber(trimmed)

            -- Check if it's a valid integer between 1 and 100
            if not num or num < 1 or num > 100 or num ~= math.floor(num) then
                return false
            end
        end

        return true
    end

    editBox:SetOnTextChanged(function(text)
        isValid = Validate(text)
        -- editBox:SetBackdropBorderColor(isValid and AF.GetColorRGB("gray") or AF.GetColorRGB("red"))
    end)

    -- Public API
    function editBox:IsValid()
        return isValid
    end

    -- Initial validation
    if editBox:GetText() ~= "" then
        local text = editBox:GetText()
        isValid = Validate(text)
        -- editBox:SetBackdropBorderColor(isValid and AF.GetColorRGB("gray") or AF.GetColorRGB("red"))
    end

    return editBox
end

--------------------------------------------------
-- Target GUID Input
--------------------------------------------------

---@class QRA_TargetGuidInput : AF_EditBox
---@field IsValid fun(self: QRA_TargetGuidInput): boolean

--- Create a target GUID/Unit input field with validation
---@param parent Frame Parent frame
---@param label string|nil Label text
---@param width number Field width
---@return QRA_TargetGuidInput editBox
function QRA.Widgets.CreateTargetGuidInput(parent, label, width)
    ---@class QRA_TargetGuidInput : AF_EditBox
    local editBox = AF.CreateEditBox(parent, label or QRA.L["Target Unit/NPC ID"], width or 200, 20)

    -- Tooltip
    AF.SetTooltip(editBox, "TOPLEFT", 0, 2,
        QRA.L["Target Unit/NPC ID"],
        "Enter target unit or NPC ID",
        "boss - Any boss reaching threshold",
        "boss1, boss2...boss8 - Specific boss",
        "12345 - NPC ID")

    -- Validation state
    local isValid = false

    -- Validate input
    local function Validate(text)
        if not text or text == "" then
            return false
        end

        local trimmed = strtrim(text)

        -- Check if it's "boss"
        if trimmed == "boss" then
            return true
        end

        -- Check if it's boss1-boss8
        if trimmed:match("^boss[1-8]$") then
            return true
        end

        -- Check if it's a numeric NPC ID
        local num = tonumber(trimmed)
        if num and num > 0 and num == math.floor(num) then
            return true
        end

        return false
    end

    editBox:SetOnTextChanged(function(text)
        isValid = Validate(text)
        -- editBox:SetBackdropBorderColor(isValid and AF.GetColorRGB("gray") or AF.GetColorRGB("red"))
    end)

    -- Public API
    function editBox:IsValid()
        return isValid
    end

    -- Initial validation
    if editBox:GetText() ~= "" then
        local text = editBox:GetText()
        isValid = Validate(text)
        -- editBox:SetBackdropBorderColor(isValid and AF.GetColorRGB("gray") or AF.GetColorRGB("red"))
    end

    return editBox
end

--------------------------------------------------
-- Countdown Slider
--------------------------------------------------

---@class QRA_Slider : AF_Slider
---@field SetCursorPosition fun(self: QRA_Slider, position: number)

--- Create a countdown time slider
---@param parent Frame Parent frame
---@param width number Slider width
---@param minVal? number Minimum value (default 0)
---@param maxVal? number Maximum value (default 30)
---@param onChange? function Callback when value changes
---@return QRA_Slider slider
function QRA.Widgets.CreateCountdownSlider(parent, width, minVal, maxVal, onChange)
    ---@class QRA_Slider : AF_Slider
    local slider = AF.CreateSlider(parent, QRA.L["Countdown (sec)"], width, minVal or 0, maxVal or 30, 1)
    slider:SetValue(5)
    slider.eb:SetCursorPosition(0)

    if onChange then
        slider:SetAfterValueChanged(function(value)
            onChange(value)
        end)
    end

    function slider:SetCursorPosition(position)
        slider.eb:SetCursorPosition(position)
    end

    return slider
end

--------------------------------------------------
-- Alert Type Selector
--------------------------------------------------

--- Create an alert type dropdown
---@param parent Frame Parent frame
---@param width number Dropdown width
---@param onSelect? function Callback when selection changes
---@return AF_Dropdown dropdown
function QRA.Widgets.CreateAlertTypeDropdown(parent, width, onSelect)
    local dropdown = AF.CreateDropdown(parent, width or 150)
    dropdown:SetLabel(QRA.L["Alert Type"])

    local items = {
        { text = QRA.L["Text-to-Speech"], value = QRA.Assignments.AlertTypes.TTS },
        { text = QRA.L["Sound"], value = QRA.Assignments.AlertTypes.SOUND },
        { text = QRA.L["On-Screen Text"], value = QRA.Assignments.AlertTypes.SCREEN },
        { text = QRA.L["Chat Message"], value = QRA.Assignments.AlertTypes.CHAT },
    }

    dropdown:SetItems(items)
    dropdown:SetSelectedValue(QRA.Assignments.AlertTypes.TTS)

    if onSelect then
        dropdown:SetOnSelect(onSelect)
    end

    return dropdown
end

--------------------------------------------------
-- Boss Selector
--------------------------------------------------

local function GetAllBosses()
    local bosses = {}
    for instanceName, instanceData in pairs(QRA.Bosses.GetAllBosses()) do
        bosses[instanceName] = {
            text = instanceName,
            notClickable = true,
            children = {},
        }
        for _, bossData in ipairs(instanceData.bosses) do
            table.insert(bosses[instanceName].children, {
                text = bossData.name,
                abbvr = bossData.abbreviation,
                encounterId = bossData.encounterId,
            })
        end
    end

    return bosses
end

--- Create a menu to select a boss
---@param parent Frame Parent frame
---@param width number Dropdown width
---@param onSelect function Callback when selection changes
---@return AF_CascadingMenuButton dropdown
function QRA.Widgets.CreateBossMenu(parent, width, onSelect)
    local menu = AF.CreateCascadingMenuButton(parent, width or 200)
    menu:SetLabel(QRA.L["Boss"])
    menu:SetItems(GetAllBosses())
    menu:SetText(QRA.L["All Instances"])
    if onSelect then
        hooksecurefunc(menu, "OnMenuSelection", onSelect)
    end

    return menu
end

--------------------------------------------------
-- Trigger Selector Dropdown
--------------------------------------------------

-- Helper function to format trigger display text with boss name
---@param trigger Trigger
local function FormatTriggerText(trigger)
    local details = trigger.spellName or trigger.targetGuid or (trigger.time and string.format("%ds", trigger.time)) or "-"
    local typeName = QRA.Triggers.Types[trigger.type].name or trigger.type

    -- Add boss name prefix if available
    local prefix = ""
    if trigger.encounterId then
        local bossData = QRA.Bosses.GetBossByEncounterId(trigger.encounterId)
        if bossData and bossData.name then
            prefix = (bossData.abbreviation or bossData.name) .. " - "
        end
    end

    return string.format("%s%s (%s)", prefix, details, typeName)
end

local function GetAllTriggersGroupedByBoss(onClick)
    -- Start with boss structure
    local bosses = GetAllBosses()
    local triggers = QRA.Triggers.GetAll()
    local triggersByBoss = {}
    local ungroupedTriggers = {}

    -- Group triggers by encounter ID
    for _, trigger in pairs(triggers) do
        if trigger.encounterId then
            if not triggersByBoss[trigger.encounterId] then
                triggersByBoss[trigger.encounterId] = {}
            end
            table.insert(triggersByBoss[trigger.encounterId], trigger)
        else
            table.insert(ungroupedTriggers, trigger)
        end
    end

    -- Extend boss structure with triggers
    local menuItems = {}
    for instanceName, instanceItem in pairs(bosses) do
        local hasTriggersInInstance = false

        for _, bossItem in ipairs(instanceItem.children) do
            bossItem.text = bossItem.abbvr or bossItem.text
            local triggersForBoss = triggersByBoss[bossItem.encounterId]

            if triggersForBoss and #triggersForBoss > 0 then
                hasTriggersInInstance = true

                -- Convert boss item to have children (triggers)
                bossItem.notClickable = true
                bossItem.children = {}

                -- Add triggers for this boss
                for _, trigger in ipairs(triggersForBoss) do
                    local details = trigger.spellName or trigger.targetGuid or (trigger.time and string.format("%ds", trigger.time)) or "-"
                    local typeName = QRA.Triggers.Types[trigger.type].name or trigger.type
                    table.insert(bossItem.children, {
                        text = string.format("%s (%s)", details, typeName),
                        value = trigger.id,
                        onClick = onClick and function()
                            onClick(trigger.id)
                        end or nil,
                    })
                end

                -- Sort triggers alphabetically
                table.sort(bossItem.children, function(a, b) return a.text < b.text end)
            end
        end

        if hasTriggersInInstance then
            menuItems[instanceName] = instanceItem
        end
    end

    return menuItems
end

---@class QRA_TriggerDropdown : AF_CascadingMenuButton
---@field GetSelectedValue fun(self: QRA_TriggerDropdown): string|nil
---@field SetSelectedValue fun(self: QRA_TriggerDropdown, triggerId: string|nil)

--- Create a cascading menu to select a trigger
---@param parent Frame Parent frame
---@param width number Menu width
---@param onSelect? function Callback when selection changes
---@return QRA_TriggerDropdown menu
function QRA.Widgets.CreateTriggerDropdown(parent, width, onSelect)
    local selectedTriggerId = nil

    ---@class QRA_TriggerDropdown : AF_CascadingMenuButton
    local menu = AF.CreateCascadingMenuButton(parent, width or 200)
    menu:SetLabel(QRA.L["Linked Trigger"])
    menu:SetItems(GetAllTriggersGroupedByBoss(function(triggerId)
            selectedTriggerId = triggerId

            -- Update display text
            local trigger = QRA.Triggers.Get(triggerId)
            if trigger then
                menu:SetText(FormatTriggerText(trigger))
            end

            -- Call user callback
            if onSelect then
                onSelect(triggerId)
            end
        end))

    hooksecurefunc(menu, "OnMenuSelection", function(self, item, path)
        self:SetText(FormatTriggerText(QRA.Triggers.Get(item.value)))
    end)

    -- Public API methods to match dropdown interface
    function menu:GetSelectedValue()
        return selectedTriggerId
    end

    function menu:SetSelectedValue(triggerId)
        selectedTriggerId = triggerId

        if triggerId then
            local trigger = QRA.Triggers.Get(triggerId)
            if trigger then
                menu:SetText(FormatTriggerText(trigger))
            end
        else
            menu:SetText(QRA.L["-- Select Trigger --"])
        end
    end

    return menu
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function QRA.Widgets.Initialize()
end
