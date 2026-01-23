--[[
    QRaidAssignments - Dev Mode: Fake Boss UI
    Simulates boss frames with HP control, spell casting, and debuff application
]]

---@class QRA
local QRA = select(2, ...)
QRA.DevMode = QRA.DevMode or {}
QRA.DevMode.UI = QRA.DevMode.UI or {}

local DevModeUI = QRA.DevMode.UI
local FakeEncounter = QRA.DevMode.FakeEncounter
local EventFirer = QRA.DevMode.EventFirer

---@type AbstractFramework
local AF = QRA.AF

--------------------------------------------------
-- Constants
--------------------------------------------------
local PANEL_WIDTH = 400
local PANEL_HEIGHT = 500
local BOSS_FRAME_HEIGHT = 80

--------------------------------------------------
-- State
--------------------------------------------------
local fakeBossPanelFrame = nil
local bossFrames = {}
local selectedTarget = nil

--------------------------------------------------
-- Helper Functions
--------------------------------------------------

--- Get class color
---@param class string
---@return number r, number g, number b
local function GetClassColor(class)
    local colors = RAID_CLASS_COLORS[class]
    if colors then
        return colors.r, colors.g, colors.b
    end
    return 1, 1, 1
end

--- Create a player selector dropdown
---@param parent Frame
---@param width number
---@param onSelect function
---@return Frame
local function CreatePlayerDropdown(parent, width, onSelect)
    local dropdown = AF.CreateDropdown(parent, width)
    dropdown:SetLabel(QRA.L["Target Player"])

    local function RefreshPlayers()
        local players = QRA.DevMode.GetAvailablePlayers()
        local items = {}

        for i, player in ipairs(players) do
            local r, g, b = GetClassColor(player.class)
            table.insert(items, {
                text = player.name,
                value = player.name,
                color = {r, g, b},
            })
        end

        dropdown:SetItems(items)
    end

    dropdown.RefreshPlayers = RefreshPlayers
    RefreshPlayers()

    if onSelect then
        dropdown:SetOnSelect(function(value)
            onSelect(value)
        end)
    end

    return dropdown
end

--------------------------------------------------
-- Boss Frame Creation
--------------------------------------------------

--- Create a fake boss frame UI element
---@param parent Frame
---@param bossData table
---@param index number
---@return Frame
local function CreateBossFrame(parent, bossData, index)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    AF.SetHeight(frame, BOSS_FRAME_HEIGHT)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(AF.GetColorRGB("gray"))

    -- Boss name
    local nameFS = AF.CreateFontString(frame, bossData.name, "accent")
    AF.SetPoint(nameFS, "TOPLEFT", frame, 10, -8)

    -- Unit ID label
    local unitFS = AF.CreateFontString(frame, bossData.unitId, "gray")
    AF.SetPoint(unitFS, "LEFT", nameFS, "RIGHT", 10, 0)

    -- HP Bar
    local hpBarBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    AF.SetHeight(hpBarBg, 20)
    AF.SetPoint(hpBarBg, "TOPLEFT", frame, 10, -30)
    AF.SetPoint(hpBarBg, "TOPRIGHT", frame, -80, -30)
    hpBarBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    hpBarBg:SetBackdropColor(0.2, 0.2, 0.2, 1)
    hpBarBg:SetBackdropBorderColor(0, 0, 0, 1)

    local hpBar = CreateFrame("Frame", nil, hpBarBg)
    hpBar:SetFrameLevel(hpBarBg:GetFrameLevel() + 1)
    AF.SetPoint(hpBar, "TOPLEFT", hpBarBg, 1, -1)
    AF.SetPoint(hpBar, "BOTTOMLEFT", hpBarBg, 1, 1)
    hpBar:SetWidth((hpBarBg:GetWidth() - 2) * (bossData.currentHealth / 100))

    local hpBarTex = hpBar:CreateTexture(nil, "ARTWORK")
    hpBarTex:SetAllPoints()
    hpBarTex:SetColorTexture(0.8, 0.1, 0.1, 1)

    -- HP text overlay (on top of the bar) - use a separate frame for proper layering
    local hpTextFrame = CreateFrame("Frame", nil, hpBarBg)
    hpTextFrame:SetAllPoints(hpBarBg)
    hpTextFrame:SetFrameLevel(hpBar:GetFrameLevel() + 2)
    local hpText = hpTextFrame:CreateFontString(nil, "OVERLAY")
    hpText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    hpText:SetPoint("CENTER", hpBarBg, "CENTER", 0, 0)
    hpText:SetText(bossData.currentHealth .. "%")
    hpText:SetTextColor(1, 1, 1, 1)

    frame.hpBar = hpBar
    frame.hpBarBg = hpBarBg
    frame.hpBarTex = hpBarTex
    frame.hpText = hpText

    --- Update HP bar display
    function frame:UpdateHealth(percent)
        local width = (self.hpBarBg:GetWidth() - 2) * (percent / 100)
        self.hpBar:SetWidth(math.max(1, width))
        self.hpText:SetText(math.floor(percent) .. "%")

        -- Color based on health
        if percent > 50 then
            self.hpBarTex:SetColorTexture(0.8, 0.1, 0.1, 1)
        elseif percent > 25 then
            self.hpBarTex:SetColorTexture(0.8, 0.5, 0.1, 1)
        else
            self.hpBarTex:SetColorTexture(0.8, 0.8, 0.1, 1)
        end
    end

    -- HP Slider
    local hpSlider = AF.CreateSlider(frame, nil, 60, 0, 100, 1)
    AF.SetPoint(hpSlider, "LEFT", hpBarBg, "RIGHT", 5, 0)
    hpSlider:SetValue(bossData.currentHealth)
    hpSlider:SetOnValueChanged(function(value)
        FakeEncounter.SetBossHealth(bossData.unitId, value)
        frame:UpdateHealth(value)
    end)

    -- Quick HP buttons
    local hpButtonsFrame = CreateFrame("Frame", nil, frame)
    AF.SetHeight(hpButtonsFrame, 20)
    AF.SetPoint(hpButtonsFrame, "TOPLEFT", hpBarBg, "BOTTOMLEFT", 0, -5)
    AF.SetPoint(hpButtonsFrame, "TOPRIGHT", frame, -10, -55)

    local hpPresets = {100, 75, 50, 25, 10, 1}
    local prevBtn = nil
    for _, hp in ipairs(hpPresets) do
        local btn = AF.CreateButton(hpButtonsFrame, hp .. "%", "static", 45, 18)
        if prevBtn then
            AF.SetPoint(btn, "LEFT", prevBtn, "RIGHT", 3, 0)
        else
            AF.SetPoint(btn, "LEFT", hpButtonsFrame, 0, 0)
        end
        btn:SetOnClick(function()
            FakeEncounter.SetBossHealth(bossData.unitId, hp)
            frame:UpdateHealth(hp)
            hpSlider:SetValue(hp)
        end)
        prevBtn = btn
    end

    frame.bossData = bossData

    return frame
end

--------------------------------------------------
-- Spell Casting Panel
--------------------------------------------------

--- Create the spell casting section
---@param parent Frame
---@return Frame
local function CreateSpellCastingSection(parent)
    local section = CreateFrame("Frame", nil, parent)
    AF.SetHeight(section, 100)

    local label = AF.CreateFontString(section, QRA.L["Cast Spell"], "accent")
    AF.SetPoint(label, "TOPLEFT", section, 0, 0)

    -- Spell input
    local spellInput = QRA.Widgets.CreateSpellInput(section, QRA.L["Spell ID"], 150, false)
    AF.SetPoint(spellInput, "TOPLEFT", label, "BOTTOMLEFT", 0, -5)

    -- Event type dropdown
    local eventDropdown = AF.CreateDropdown(section, 150)
    eventDropdown:SetLabel(QRA.L["Event Type"])
    AF.SetPoint(eventDropdown, "LEFT", spellInput, "RIGHT", 10, 0)
    eventDropdown:SetItems({
        { text = QRA.L["Spell Cast Success"], value = "SPELL_CAST_SUCCESS" },
        { text = QRA.L["Spell Cast Start"], value = "SPELL_CAST_START" },
        { text = QRA.L["Aura Applied"], value = "SPELL_AURA_APPLIED" },
        { text = QRA.L["Aura Removed"], value = "SPELL_AURA_REMOVED" },
    })
    eventDropdown:SetSelectedValue("SPELL_CAST_SUCCESS")

    -- Target dropdown (for auras)
    local targetDropdown = CreatePlayerDropdown(section, 150, function(playerName)
        selectedTarget = playerName
    end)
    AF.SetPoint(targetDropdown, "TOPLEFT", spellInput, "BOTTOMLEFT", 0, -10)

    -- Duration input (for auras)
    local durationInput = AF.CreateEditBox(section, QRA.L["Duration (sec)"], 80, 20)
    AF.SetPoint(durationInput, "LEFT", targetDropdown, "RIGHT", 10, 0)
    durationInput:SetText("0")

    -- Cast button
    local castBtn = AF.CreateButton(section, QRA.L["Cast"], "softlime", 80, 28)
    AF.SetPoint(castBtn, "LEFT", durationInput, "RIGHT", 15, 0)
    castBtn:SetOnClick(function()
        local spellData = spellInput:GetSpell()
        if not spellData.spellId then
            QRA.Print(QRA.L["DevMode: Enter a valid spell ID"])
            return
        end

        local eventType = eventDropdown:GetSelectedValue()
        local duration = tonumber(durationInput:GetText()) or 0

        if eventType == "SPELL_CAST_SUCCESS" then
            EventFirer.FireSpellCastSuccess(spellData.spellId, "boss1", selectedTarget)
        elseif eventType == "SPELL_CAST_START" then
            EventFirer.FireSpellCastStart(spellData.spellId, "boss1")
        elseif eventType == "SPELL_AURA_APPLIED" then
            EventFirer.FireAuraApplied(spellData.spellId, selectedTarget, "boss1", duration)
        elseif eventType == "SPELL_AURA_REMOVED" then
            EventFirer.FireAuraRemoved(spellData.spellId, selectedTarget, "boss1")
        end
    end)

    section.targetDropdown = targetDropdown

    return section
end

--------------------------------------------------
-- Debuff Application Panel
--------------------------------------------------

--- Create the debuff application section
---@param parent Frame
---@return Frame
local function CreateDebuffSection(parent)
    local section = CreateFrame("Frame", nil, parent)
    AF.SetHeight(section, 80)

    local label = AF.CreateFontString(section, QRA.L["Apply Debuff to Players"], "accent")
    AF.SetPoint(label, "TOPLEFT", section, 0, 0)

    -- Debuff spell input
    local debuffInput = QRA.Widgets.CreateSpellInput(section, QRA.L["Debuff Spell ID"], 150, false)
    AF.SetPoint(debuffInput, "TOPLEFT", label, "BOTTOMLEFT", 0, -5)

    -- Duration input
    local durationInput = AF.CreateEditBox(section, QRA.L["Duration"], 60, 20)
    AF.SetPoint(durationInput, "LEFT", debuffInput, "RIGHT", 10, 0)
    durationInput:SetText("10")

    -- Target dropdown
    local targetDropdown = CreatePlayerDropdown(section, 120, function(playerName)
        selectedTarget = playerName
    end)
    AF.SetPoint(targetDropdown, "LEFT", durationInput, "RIGHT", 10, 0)

    -- Apply button
    local applyBtn = AF.CreateButton(section, QRA.L["Apply"], "lime", 60, 26)
    AF.SetPoint(applyBtn, "TOPLEFT", debuffInput, "BOTTOMLEFT", 0, -8)
    applyBtn:SetOnClick(function()
        local spellData = debuffInput:GetSpell()
        if not spellData.spellId then
            QRA.Print(QRA.L["DevMode: Enter a valid spell ID"])
            return
        end

        local duration = tonumber(durationInput:GetText()) or 10
        EventFirer.FireAuraApplied(spellData.spellId, selectedTarget, "boss1", duration)
    end)

    -- Remove button
    local removeBtn = AF.CreateButton(section, QRA.L["Remove"], "red", 60, 26)
    AF.SetPoint(removeBtn, "LEFT", applyBtn, "RIGHT", 10, 0)
    removeBtn:SetOnClick(function()
        local spellData = debuffInput:GetSpell()
        if not spellData.spellId then
            QRA.Print(QRA.L["DevMode: Enter a valid spell ID"])
            return
        end

        EventFirer.FireAuraRemoved(spellData.spellId, selectedTarget, "boss1")
    end)

    section.targetDropdown = targetDropdown

    return section
end

--------------------------------------------------
-- Main Panel Creation
--------------------------------------------------

--- Create the fake boss panel
function DevModeUI.CreateFakeBossPanel()
    if fakeBossPanelFrame then
        return fakeBossPanelFrame
    end

    local frame = AF.CreateHeaderedFrame(UIParent, "QRA_DevMode_FakeBossPanel", QRA.L["DevMode: Fake Boss Simulator"], PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        QRA.DevMode.SaveFramePosition(self, "fakeBossPanel")
    end)

    -- Apply saved position or offset from test panel
    if not QRA.DevMode.ApplyWindowPosition(frame, "fakeBossPanel") then
        frame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end

    fakeBossPanelFrame = frame

    -- Content area
    local content = CreateFrame("Frame", nil, frame)
    AF.SetPoint(content, "TOPLEFT", frame, 10, -35)
    AF.SetPoint(content, "BOTTOMRIGHT", frame, -10, 10)

    -- Status message when no encounter
    local noEncounterFS = AF.CreateFontString(content, QRA.L["Start an encounter to see boss frames"], "gray")
    noEncounterFS:SetPoint("TOP", content, 0, -20)
    content.noEncounterFS = noEncounterFS

    -- Boss frames container (scrollable)
    local bossContainer = CreateFrame("Frame", nil, content)
    AF.SetPoint(bossContainer, "TOPLEFT", content, 0, 0)
    AF.SetPoint(bossContainer, "TOPRIGHT", content, 0, 0)
    AF.SetHeight(bossContainer, 200)
    content.bossContainer = bossContainer

    -- Spell casting section
    local spellSection = CreateSpellCastingSection(content)
    AF.SetPoint(spellSection, "TOPLEFT", bossContainer, "BOTTOMLEFT", 0, -10)
    AF.SetPoint(spellSection, "TOPRIGHT", bossContainer, "BOTTOMRIGHT", 0, -10)
    content.spellSection = spellSection

    -- Debuff section
    local debuffSection = CreateDebuffSection(content)
    AF.SetPoint(debuffSection, "TOPLEFT", spellSection, "BOTTOMLEFT", 0, -10)
    AF.SetPoint(debuffSection, "TOPRIGHT", spellSection, "BOTTOMRIGHT", 0, -10)
    content.debuffSection = debuffSection

    -- Close button
    local closeBtn = AF.CreateButton(content, QRA.L["Close"], "red", 80, 26)
    AF.SetPoint(closeBtn, "BOTTOMRIGHT", content, 0, 5)
    closeBtn:SetOnClick(function()
        frame:Hide()
    end)

    -- Refresh boss frames function
    function DevModeUI.RefreshBossFrames()
        -- Clear existing boss frames
        for _, bf in pairs(bossFrames) do
            bf:Hide()
            bf:SetParent(nil)
        end
        wipe(bossFrames)

        if not FakeEncounter.IsActive() then
            noEncounterFS:Show()
            bossContainer:SetHeight(50)
            return
        end

        noEncounterFS:Hide()

        local bosses = FakeEncounter.GetFakeBosses()
        local prevFrame = nil

        for i, bossData in ipairs(bosses) do
            local bossFrame = CreateBossFrame(bossContainer, bossData, i)
            AF.SetPoint(bossFrame, "TOPLEFT", bossContainer, 0, prevFrame and (-i * (BOSS_FRAME_HEIGHT + 5) + BOSS_FRAME_HEIGHT + 5) or 0)
            AF.SetPoint(bossFrame, "TOPRIGHT", bossContainer, 0, prevFrame and (-i * (BOSS_FRAME_HEIGHT + 5) + BOSS_FRAME_HEIGHT + 5) or 0)
            bossFrame:UpdateHealth(bossData.currentHealth)
            table.insert(bossFrames, bossFrame)
            prevFrame = bossFrame
        end

        -- Adjust container height
        bossContainer:SetHeight(#bosses * (BOSS_FRAME_HEIGHT + 5))

        -- Refresh player dropdowns
        if spellSection.targetDropdown.RefreshPlayers then
            spellSection.targetDropdown.RefreshPlayers()
        end
        if debuffSection.targetDropdown.RefreshPlayers then
            debuffSection.targetDropdown.RefreshPlayers()
        end
    end

    -- Listen for encounter state changes to auto-refresh
    local originalOnEncounterStateChanged = FakeEncounter.OnEncounterStateChanged
    FakeEncounter.OnEncounterStateChanged = function(active, bossName, encounterId)
        -- Call original handler if exists
        if originalOnEncounterStateChanged then
            originalOnEncounterStateChanged(active, bossName, encounterId)
        end
        -- Refresh boss frames if panel is visible
        if fakeBossPanelFrame and fakeBossPanelFrame:IsShown() then
            DevModeUI.RefreshBossFrames()
        end
    end

    return frame
end

--------------------------------------------------
-- Panel Show/Hide
--------------------------------------------------

function DevModeUI.ShowFakeBossPanel()
    if not fakeBossPanelFrame then
        DevModeUI.CreateFakeBossPanel()
    end

    fakeBossPanelFrame:Show()
    DevModeUI.RefreshBossFrames()
end

function DevModeUI.HideFakeBossPanel()
    if fakeBossPanelFrame then
        fakeBossPanelFrame:Hide()
    end
end

function DevModeUI.ToggleFakeBossPanel()
    if fakeBossPanelFrame and fakeBossPanelFrame:IsShown() then
        DevModeUI.HideFakeBossPanel()
    else
        DevModeUI.ShowFakeBossPanel()
    end
end
