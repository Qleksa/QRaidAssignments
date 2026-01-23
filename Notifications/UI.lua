---@class QRA
local QRA = select(2, ...)

QRA.Notifications.UI = {}

local AF = _G.AbstractFramework

---@class QRA_ScreenMessageFrame : AF_BorderedFrame
---@field text AF_FontString
---@field fadeAnim AnimationGroup
---@field Init fun(self: QRA_ScreenMessageFrame, message: string, spellId: number, seconds: number)
---@field SetCountdownText fun(self: QRA_ScreenMessageFrame, text: string)
---@field SetMessageText fun(self: QRA_ScreenMessageFrame, text: string)
---@field SetBarValue fun(self: QRA_ScreenMessageFrame, value: number)
---@field SetSpell fun(self: QRA_ScreenMessageFrame, spellId: number)
---@field HideBar fun(self: QRA_ScreenMessageFrame)
---@field FadeOut fun(self: QRA_ScreenMessageFrame, delay: number)
---@field UpdateCountdown fun(self: QRA_ScreenMessageFrame, seconds: number)
---@field UpdatePosition fun(self: QRA_ScreenMessageFrame, point: string, xOfs: number, yOfs: number)

--- Create the screen message display frame
---@param framePosition QRA_FramePosition
---@return QRA_ScreenMessageFrame
local function CreateScreenMessageFrame(framePosition)
    local progressBarMaxValue = 100

    local screenMessageFrame = AF.CreateBorderedFrame(QRA.UIParent, "QRA_ScreenMessageFrame", 250, 80, nil, "softlime")
    AF.SetPoint(screenMessageFrame, framePosition.point, framePosition.xOfs, framePosition.yOfs)
    screenMessageFrame:SetFrameStrata("DIALOG")
    screenMessageFrame:Hide()

    -- Spell icon
    local icon = screenMessageFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    AF.SetPoint(icon, "LEFT", screenMessageFrame, 15, 0)
    screenMessageFrame.icon = icon

    -- Spell name
    local text = AF.CreateFontString(screenMessageFrame, "", "softlime")
    AF.SetPoint(text, "LEFT", icon, "RIGHT", 10, 10)
    screenMessageFrame.text = text

    -- Countdown text
    local countText = AF.CreateFontString(screenMessageFrame, "", "yellow")
    AF.SetPoint(countText, "LEFT", icon, "RIGHT", 10, -10)
    screenMessageFrame.countText = countText

    -- Progress bar
    local progressBar = AF.CreateBlizzardStatusBar(screenMessageFrame, 0, progressBarMaxValue, 200, 8, "softlime")
    AF.SetPoint(progressBar, "BOTTOM", screenMessageFrame, 0, 10)
    screenMessageFrame.progressBar = progressBar

    -- Animation group for fade out
    local ag = screenMessageFrame:CreateAnimationGroup()
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(0.5)
    fade:SetStartDelay(4.5)
    ag:SetScript("OnFinished", function()
        screenMessageFrame:Hide()
        screenMessageFrame:SetAlpha(1)
    end)
    screenMessageFrame.fadeAnim = ag

    -- Public API
    function screenMessageFrame:Init(message, spellId, seconds)
        self:SetMessageText(message)
        self:SetSpell(spellId)
        self:SetCountdownText("in " .. seconds)
        self:SetBarValue(100)
    end

    function screenMessageFrame:SetCountdownText(text)
        self.countText:SetText(text)
    end

    function screenMessageFrame:SetMessageText(text)
        self.text:SetText(text)
    end

    function screenMessageFrame:SetBarValue(value)
        self.progressBar:SetBarValue(value)
    end

    function screenMessageFrame:HideBar()
        self.progressBar:Hide()
        AF.SetPoint(self.text, "LEFT", self.icon, "RIGHT", 10, 0)
    end

    function screenMessageFrame:SetSpell(spellId)
        self.icon:SetTexture(134400)
        if spellId then
            local spellIcon = C_Spell.GetSpellTexture(spellId) or 134400
            self.icon:SetTexture(spellIcon)
        end
    end

    function screenMessageFrame:FadeOut(delay)
        QRA.Debug("Notifications: Screen - Fading out in", delay, "seconds")
        self.fadeAnim:Stop()
        self.fadeAnim:GetAnimations():SetStartDelay(delay)
        self.fadeAnim:Play()
    end

    function screenMessageFrame:UpdatePosition(point, xOfs, yOfs)
        AF.SetPoint(self, point, xOfs, yOfs)
    end

    function screenMessageFrame:UpdateCountdown(seconds)
        if seconds <= 0 then
            self:SetCountdownText(AF.WrapTextInColor("NOW!", "red"))
            self:SetBarValue(0)
            self:FadeOut(1.5)
        else
            self:SetCountdownText("in " .. math.ceil(seconds))
        end
    end

    return screenMessageFrame
end

--- Create the screen message frame for notifications
---@param framePosition QRA_FramePosition
---@return QRA_ScreenMessageFrame
function QRA.Notifications.UI.CreateScreenMessageFrame(framePosition)
    return CreateScreenMessageFrame(framePosition)
end
