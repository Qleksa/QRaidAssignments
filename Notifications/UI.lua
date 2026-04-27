---@class QRA
local QRA = select(2, ...)

QRA.Notifications.UI = {}

local AF = _G.AbstractFramework

--------------------------------------------------
-- Constants
--------------------------------------------------
local MAX_NOTIFICATION_FRAMES = 5
local FRAME_HEIGHT = 80
local FRAME_SPACING = 10
local BASE_Y_OFFSET = -150

--------------------------------------------------
-- Frame Pool State
--------------------------------------------------
local framePool = {}           -- Available frames
local activeFrameCount = 0     -- Number of frames currently in use
local frameIndex = 0           -- Counter for unique frame names

---@class QRA_ScreenMessageFrame : AF_BorderedFrame
---@field text AF_FontString
---@field fadeAnim AnimationGroup
---@field borderPulseAnim AnimationGroup
---@field slotIndex number Position slot (1-5)
---@field isAudioActive boolean Whether this frame controls countdown audio
---@field Init fun(self: QRA_ScreenMessageFrame, message: string, spellId: number, seconds: number)
---@field SetCountdownText fun(self: QRA_ScreenMessageFrame, text: string)
---@field SetMessageText fun(self: QRA_ScreenMessageFrame, text: string)
---@field SetBarValue fun(self: QRA_ScreenMessageFrame, value: number)
---@field SetSpell fun(self: QRA_ScreenMessageFrame, spellId: number)
---@field HideBar fun(self: QRA_ScreenMessageFrame)
---@field ShowBar fun(self: QRA_ScreenMessageFrame)
---@field FadeOut fun(self: QRA_ScreenMessageFrame, delay: number)
---@field UpdateCountdown fun(self: QRA_ScreenMessageFrame, seconds: number)
---@field SetSlotPosition fun(self: QRA_ScreenMessageFrame, slotIndex: number, basePosition: QRA_FramePosition)
---@field SetAudioActive fun(self: QRA_ScreenMessageFrame, isActive: boolean)
---@field Reset fun(self: QRA_ScreenMessageFrame)

--- Create the screen message display frame
---@param frameName string Unique frame name
---@return QRA_ScreenMessageFrame
local function CreateScreenMessageFrame(frameName)
    local progressBarMaxValue = 100

    ---@class QRA_ScreenMessageFrame : AF_BorderedFrame
    local screenMessageFrame = AF.CreateBorderedFrame(QRA.UIParent, frameName, 250, 80, nil, "softlime")
    screenMessageFrame:SetFrameStrata("DIALOG")
    screenMessageFrame:Hide()

    screenMessageFrame.defaultBorderColor = {AF.GetColorRGB("softlime")}
    screenMessageFrame.activeBorderColor = {AF.GetColorRGB("yellow")}
    screenMessageFrame.slotIndex = 0
    screenMessageFrame.isAudioActive = false

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
    local fadeAg = screenMessageFrame:CreateAnimationGroup()
    local fade = fadeAg:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(0.5)
    fade:SetStartDelay(0)
    fadeAg:SetScript("OnFinished", function()
        screenMessageFrame:Hide()
        screenMessageFrame:SetAlpha(1)
        -- Notify that frame can be released
        if screenMessageFrame.onFadeComplete then
            screenMessageFrame.onFadeComplete(screenMessageFrame)
        end
    end)
    screenMessageFrame.fadeAnim = fadeAg

    local pulseAg = screenMessageFrame:CreateAnimationGroup()
    pulseAg:SetLooping("REPEAT")

    local pulseOut = pulseAg:CreateAnimation("Alpha")
    pulseOut:SetFromAlpha(1)
    pulseOut:SetToAlpha(0.5)
    pulseOut:SetDuration(0.5)
    pulseOut:SetOrder(1)
    pulseOut:SetSmoothing("IN_OUT")

    local pulseIn = pulseAg:CreateAnimation("Alpha")
    pulseIn:SetFromAlpha(0.5)
    pulseIn:SetToAlpha(1)
    pulseIn:SetDuration(0.5)
    pulseIn:SetOrder(2)
    pulseIn:SetSmoothing("IN_OUT")

    screenMessageFrame.borderPulseAnim = pulseAg

    -- Public API
    function screenMessageFrame:Init(message, spellId, seconds)
        self:SetMessageText(message)
        self:SetSpell(spellId)
        self:SetCountdownText("in " .. seconds)
        self:SetBarValue(100)
        self:ShowBar()
        self.fadeAnim:Stop()
        self:SetAlpha(1)
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
        AF.SetPoint(self.countText, "LEFT", self.icon, "RIGHT", 10, 0)
    end

    function screenMessageFrame:ShowBar()
        self.progressBar:Show()
        AF.SetPoint(self.text, "LEFT", self.icon, "RIGHT", 10, 10)
        AF.SetPoint(self.countText, "LEFT", self.icon, "RIGHT", 10, -10)
    end

    function screenMessageFrame:SetSpell(spellId)
        self.icon:SetTexture(134400)
        if spellId then
            local spellIcon = C_Spell.GetSpellTexture(spellId) or 134400
            self.icon:SetTexture(spellIcon)
        end
    end

    function screenMessageFrame:FadeOut(delay)
        self.fadeAnim:Stop()
        self.fadeAnim:GetAnimations():SetStartDelay(delay or 0)
        self.fadeAnim:Play()
    end

    function screenMessageFrame:SetSlotPosition(slotIndex, basePosition)
        self.slotIndex = slotIndex
        local yOffset = basePosition.yOfs + ((slotIndex - 1) * -(FRAME_HEIGHT + FRAME_SPACING))
        self:ClearAllPoints()
        AF.SetPoint(self, basePosition.point, basePosition.xOfs, yOffset)
    end

    function screenMessageFrame:SetAudioActive(isActive)
        if self.isAudioActive == isActive then return end

        self.isAudioActive = isActive

        if isActive then
            self:SetBackdropBorderColor(unpack(self.activeBorderColor))
            self.borderPulseAnim:Play()
        else
            self.borderPulseAnim:Stop()
            self:SetBackdropBorderColor(unpack(self.defaultBorderColor))
            self:SetAlpha(1)
        end
    end

    function screenMessageFrame:UpdateCountdown(seconds)
        if seconds <= 0 then
            self:SetCountdownText(AF.WrapTextInColor("NOW!", "red"))
            self:SetBarValue(0)
        else
            self:SetCountdownText("in " .. math.ceil(seconds))
        end
    end

    function screenMessageFrame:Reset()
        self.fadeAnim:Stop()
        self.borderPulseAnim:Stop()
        self:SetAlpha(1)
        self:SetBackdropBorderColor(unpack(self.defaultBorderColor))
        self.isAudioActive = false
        self.slotIndex = 0
        self.onFadeComplete = nil
        self:SetMessageText("")
        self:SetCountdownText("")
        self:SetSpell(nil)
        self:SetBarValue(0)
        self:Hide()
    end

    return screenMessageFrame
end

--------------------------------------------------
-- Frame Pool Management
--------------------------------------------------

--- Initialize the frame pool with pre-created frames
---@param basePosition QRA_FramePosition
function QRA.Notifications.UI.InitializeFramePool(basePosition)
    for i = 1, MAX_NOTIFICATION_FRAMES do
        frameIndex = frameIndex + 1
        local frame = CreateScreenMessageFrame("QRA_NotificationFrame_" .. frameIndex)
        frame.poolIndex = i
        table.insert(framePool, frame)
    end

    QRA.Notifications.UI.basePosition = basePosition

    QRA.Debug("Notifications.UI: Frame pool initialized with", MAX_NOTIFICATION_FRAMES, "frames")
end

--- Acquire a frame from the pool
---@return QRA_ScreenMessageFrame|nil frame, number|nil slotIndex
function QRA.Notifications.UI.AcquireFrame()
    if #framePool == 0 then
        QRA.Debug("Notifications.UI: No frames available in pool")
        return nil, nil
    end

    local frame = table.remove(framePool)
    activeFrameCount = activeFrameCount + 1

    local slotIndex = activeFrameCount
    frame:SetSlotPosition(slotIndex, QRA.Notifications.UI.basePosition)

    QRA.Debug("Notifications.UI: Acquired frame, slot", slotIndex, "pool remaining:", #framePool)

    return frame, slotIndex
end

--- Release a frame back to the pool
---@param frame QRA_ScreenMessageFrame
function QRA.Notifications.UI.ReleaseFrame(frame)
    if not frame then return end

    frame:Reset()

    table.insert(framePool, frame)
    activeFrameCount = math.max(0, activeFrameCount - 1)

    QRA.Debug("Notifications.UI: Released frame, pool size:", #framePool)
end

--- Release all active frames back to pool
function QRA.Notifications.UI.ReleaseAllFrames()
    activeFrameCount = 0
    QRA.Debug("Notifications.UI: All frames marked for release")
end

--- Get the number of available frames
---@return number
function QRA.Notifications.UI.GetAvailableFrameCount()
    return #framePool
end

--- Get the maximum number of frames
---@return number
function QRA.Notifications.UI.GetMaxFrames()
    return MAX_NOTIFICATION_FRAMES
end

--- Update base position for all future frame acquisitions
---@param point string
---@param xOfs number
---@param yOfs number
function QRA.Notifications.UI.UpdateBasePosition(point, xOfs, yOfs)
    QRA.Notifications.UI.basePosition = {
        point = point,
        xOfs = xOfs,
        yOfs = yOfs,
    }
end

--------------------------------------------------
-- Legacy API (for mover compatibility)
--------------------------------------------------

--- Create a single frame for mover reference
---@param framePosition QRA_FramePosition
---@return QRA_ScreenMessageFrame
function QRA.Notifications.UI.CreateMoverReferenceFrame(framePosition)
    local frame = CreateScreenMessageFrame("QRA_NotificationMoverReference")
    frame:SetSlotPosition(1, framePosition)
    frame:Hide()
    return frame
end
