--[[
    QRaidAssignments - Notifications System
    Handles TTS, sound playback, on-screen messages, and countdown alerts
    Supports multiple simultaneous notifications with frame pooling
]]

---@class QRA
local QRA = select(2, ...)

QRA.Notifications = QRA.Notifications or {}

---@type AbstractFramework
local AF = _G.AbstractFramework

--------------------------------------------------
-- Configuration
--------------------------------------------------

---@class QRA_CountdownSounds
---@field [number] string Sound file path

---@class QRA_FramePosition
---@field point string Anchor point
---@field xOfs number X offset
---@field yOfs number Y offset

---@class QRA_NotificationConfig
---@field ttsEnabled boolean
---@field soundEnabled boolean
---@field screenEnabled boolean
---@field chatEnabled boolean
---@field screenDuration number
---@field screenPosition string
---@field chatChannel string
---@field countdownSounds QRA_CountdownSounds
---@field framePosition QRA_FramePosition
local config = {
    ttsEnabled = true,
    soundEnabled = true,
    screenEnabled = true,
    chatEnabled = true,

    screenDuration = 5,        -- Default screen message duration
    screenPosition = "CENTER", -- Where to show screen messages
    chatChannel = "SAY",       -- Default chat channel

    countdownSounds = {
        [10] = "Interface/AddOns/QRaidAssignments/Media/Sounds/10.ogg",
        [9] = "Interface/AddOns/QRaidAssignments/Media/Sounds/9.ogg",
        [8] = "Interface/AddOns/QRaidAssignments/Media/Sounds/8.ogg",
        [7] = "Interface/AddOns/QRaidAssignments/Media/Sounds/7.ogg",
        [6] = "Interface/AddOns/QRaidAssignments/Media/Sounds/6.ogg",
        [5] = "Interface/AddOns/QRaidAssignments/Media/Sounds/5.ogg",
        [4] = "Interface/AddOns/QRaidAssignments/Media/Sounds/4.ogg",
        [3] = "Interface/AddOns/QRaidAssignments/Media/Sounds/3.ogg",
        [2] = "Interface/AddOns/QRaidAssignments/Media/Sounds/2.ogg",
        [1] = "Interface/AddOns/QRaidAssignments/Media/Sounds/1.ogg",
    },

    framePosition = {
        point = "TOP",
        xOfs = 0,
        yOfs = -150,
    }
}

local MOVER_GROUP = "QRA Movers"

--------------------------------------------------
-- Active Notifications State
--------------------------------------------------

---@class QRA_ActiveNotification
---@field frame QRA_ScreenMessageFrame
---@field assignment Assignment
---@field remaining number Seconds remaining
---@field totalDuration number Total countdown duration
---@field startTime number GetTime() when started
---@field ticker TickerCallback?
---@field id string Unique notification ID

---@type QRA_ActiveNotification[]
local activeNotifications = {}

---@type QRA_ScreenMessageFrame Reference frame for mover
local moverReferenceFrame = nil

--------------------------------------------------
-- TTS Queue State
--------------------------------------------------

---@class QRA_TTSQueueEntry
---@field message string
---@field voice number|nil

---@type QRA_TTSQueueEntry[]
local ttsQueue = {}
local isTTSSpeaking = false

--------------------------------------------------
-- Notification ID Generation
--------------------------------------------------
local notificationIdCounter = 0

local function GenerateNotificationId()
    notificationIdCounter = notificationIdCounter + 1
    return "notif_" .. GetTime() .. "_" .. notificationIdCounter
end

--------------------------------------------------
-- Audio Priority Management
--------------------------------------------------

--- Find the notification with shortest remaining time (controls audio)
---@return QRA_ActiveNotification|nil
local function GetAudioPriorityNotification()
    local priority = nil
    local shortestRemaining = math.huge

    for _, notif in ipairs(activeNotifications) do
        if notif.remaining > 0 and notif.remaining < shortestRemaining then
            shortestRemaining = notif.remaining
            priority = notif
        end
    end

    return priority
end

--- Update which notification has the audio active indicator
local function UpdateAudioPriorityIndicators()
    local priorityNotif = GetAudioPriorityNotification()

    for _, notif in ipairs(activeNotifications) do
        local isActive = (priorityNotif and notif.id == priorityNotif.id)
        notif.frame:SetAudioActive(isActive)
    end
end

--------------------------------------------------
-- Frame Position Management
--------------------------------------------------

local function UpdateFramePosition(point, x, y)
    config.framePosition.point = point
    config.framePosition.xOfs = x
    config.framePosition.yOfs = y

    -- Update the base position for future frames
    QRA.Notifications.UI.UpdateBasePosition(point, x, y)

    -- Update mover reference frame position
    if moverReferenceFrame then
        moverReferenceFrame:ClearAllPoints()
        AF.SetPoint(moverReferenceFrame, point, x, y)
    end
end

--------------------------------------------------
-- Notification Lifecycle
--------------------------------------------------

--- Remove a notification from active list
---@param notificationId string
local function RemoveNotification(notificationId)
    for i, notif in ipairs(activeNotifications) do
        if notif.id == notificationId then
            if notif.ticker then
                notif.ticker:Cancel()
            end

            QRA.Notifications.UI.ReleaseFrame(notif.frame)

            table.remove(activeNotifications, i)

            UpdateAudioPriorityIndicators()

            QRA.Debug("Notifications: Removed notification", notificationId, "active count:", #activeNotifications)
            return
        end
    end
end

--- Release a notification after fade completes
---@param frame QRA_ScreenMessageFrame
local function OnNotificationFadeComplete(frame)
    for i, notif in ipairs(activeNotifications) do
        if notif.frame == frame then
            if notif.ticker then
                notif.ticker:Cancel()
            end

            QRA.Notifications.UI.ReleaseFrame(frame)

            table.remove(activeNotifications, i)

            UpdateAudioPriorityIndicators()

            QRA.Debug("Notifications: Fade complete, released notification, active count:", #activeNotifications)
            return
        end
    end
end

--------------------------------------------------
-- Public API
--------------------------------------------------

---@param type AlertType Notification type
---@param message string Message
---@param file string|nil Sound file for SOUND type
function QRA.Notifications.Notify(type, message, file)
    if type == "TTS" then
        QRA.Notifications.SpeakTTS(message)
    elseif type == "SOUND" then
        QRA.Notifications.PlaySound(file)
    elseif type == "SCREEN" then
        QRA.Notifications.ShowOnScreen(message)
    elseif type == "CHAT" then
        QRA.Notifications.SendChat(message)
    end
end

--------------------------------------------------
-- Text-to-Speech (with Queue)
--------------------------------------------------

--- Process the TTS queue
local function ProcessTTSQueue()
    if isTTSSpeaking or #ttsQueue == 0 then
        return
    end

    local entry = table.remove(ttsQueue, 1)
    if not entry or not entry.message or entry.message == "" then
        ProcessTTSQueue()
        return
    end

    isTTSSpeaking = true

    if C_VoiceChat and C_VoiceChat.SpeakText then
        local voiceId = entry.voice or Enum.TtsVoiceType.Alternate
        C_VoiceChat.SpeakText(
            voiceId,
            entry.message,
            C_TTSSettings and C_TTSSettings.GetSpeechRate() or 1,
            C_TTSSettings and C_TTSSettings.GetSpeechVolume() or 100
        )

        local wordCount = select(2, entry.message:gsub("%S+", ""))
        local estimatedDuration = (wordCount * 0.4) + 0.5

        C_Timer.After(estimatedDuration, function()
            isTTSSpeaking = false
            ProcessTTSQueue()
        end)
    else
        isTTSSpeaking = false
        QRA.Print("Issue with TTS: C_VoiceChat.SpeakText not available")
    end
end

--- Speak a message using TTS (queued)
---@param message string The message to speak
---@param voice integer|nil Optional voice identifier
function QRA.Notifications.SpeakTTS(message, voice)
    if not config.ttsEnabled then return end
    if not message or message == "" then return end

    table.insert(ttsQueue, {
        message = message,
        voice = voice,
    })

    ProcessTTSQueue()
end

--- Clear the TTS queue
function QRA.Notifications.ClearTTSQueue()
    wipe(ttsQueue)
    isTTSSpeaking = false
end

--------------------------------------------------
-- Sound Playback
--------------------------------------------------

--- Play a sound file
---@param soundFile string|nil Path to the sound file
---@param channel string|nil Sound channel (Master, SFX, Music, Ambience, Dialog)
function QRA.Notifications.PlaySound(soundFile, channel)
    if not config.soundEnabled then return end

    if soundFile then
        PlaySoundFile(soundFile, channel or "Master")
    else
        -- Default alert sound
        PlaySound(SOUNDKIT.RAID_WARNING, channel or "Master")
    end
end

--- Play a countdown sound for the given number
---@param number number The countdown number (1 up to 10)
---@param useDefault boolean|nil Whether to use the default sound instead of custom
function QRA.Notifications.PlayCountdown(number, useDefault)
    if not config.soundEnabled then return end
    if (number < 1) or (number > 10) then return end

    local soundFile = config.countdownSounds[number]
    if not useDefault and soundFile then
        PlaySoundFile(soundFile, "Master")
    else
        -- Fallback to default sound
        PlaySound(SOUNDKIT.UI_BATTLEGROUND_COUNTDOWN_TIMER, "Master")
    end
end

--------------------------------------------------
-- On-Screen Messages
--------------------------------------------------

--- Show a message on screen (uses frame pool)
---@param message string The message to display
---@param duration number|nil Duration in seconds (default 5)
---@param color table|nil RGB color table {r, g, b}
function QRA.Notifications.ShowOnScreen(message, duration, color)
    if not config.screenEnabled then return end

    -- Acquire a frame from the pool
    local frame, slotIndex = QRA.Notifications.UI.AcquireFrame()
    if not frame then
        QRA.Debug("Notifications: No frames available for screen message")
        return
    end

    frame:SetMessageText(message)
    frame.text:SetTextColor(1, 1, 0)
    if color then
        frame.text:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 0)
    end
    frame:SetCountdownText("")
    frame:HideBar()

    frame:SetAlpha(1)
    frame:Show()

    frame.onFadeComplete = OnNotificationFadeComplete

    local notificationId = GenerateNotificationId()
    local notification = {
        id = notificationId,
        frame = frame,
        assignment = nil,
        remaining = 0,
        totalDuration = 0,
        startTime = GetTime(),
        ticker = nil,
    }
    table.insert(activeNotifications, notification)

    frame:FadeOut(duration or config.screenDuration)
end

--- Show a countdown notification for an assignment
---@param assignment Assignment The assignment starting countdown
---@param seconds number Seconds remaining
function QRA.Notifications.ShowCountdown(assignment, seconds)
    if not config.screenEnabled then return end

    local frame, slotIndex = QRA.Notifications.UI.AcquireFrame()
    if not frame then
        QRA.Debug("Notifications: No frames available for countdown")
        return
    end

    local message = assignment.message
    if (not message or message == "") and assignment.spellName then
        message = string.format("Use %s", assignment.spellName)
        if assignment.targetPlayer and assignment.targetPlayer ~= "" then
            message = message .. " on " .. assignment.targetPlayer
        end
    end
    message = message or "Assignment triggered!"

    frame:Init(message, assignment.spellId, seconds)
    frame:Show()

    frame.onFadeComplete = OnNotificationFadeComplete

    local notificationId = GenerateNotificationId()
    local startTime = GetTime()

    ---@type QRA_ActiveNotification
    local notification = {
        id = notificationId,
        frame = frame,
        assignment = assignment,
        remaining = seconds,
        totalDuration = seconds,
        startTime = startTime,
        ticker = nil,
    }

    table.insert(activeNotifications, notification)

    UpdateAudioPriorityIndicators()

    local priorityNotif = GetAudioPriorityNotification()
    if priorityNotif and priorityNotif.id == notificationId then
        QRA.Notifications.PlayCountdown(seconds)
    end

    notification.ticker = C_Timer.NewTicker(1, function()
        local elapsed = GetTime() - startTime
        notification.remaining = seconds - elapsed

        if notification.remaining > 0 then
            frame:SetBarValue((notification.remaining / seconds) * 100)
            frame:UpdateCountdown(math.ceil(notification.remaining))

            local currentPriority = GetAudioPriorityNotification()
            if currentPriority and currentPriority.id == notificationId then
                QRA.Notifications.PlayCountdown(math.ceil(notification.remaining))
            end

            UpdateAudioPriorityIndicators()
        else
            frame:UpdateCountdown(0)
            frame:FadeOut(1.5)
        end
    end, seconds)

    QRA.Debug("Notifications: Started countdown", notificationId, "for", seconds, "seconds, active count:", #activeNotifications)
end

--- Cancel all active countdown notifications
function QRA.Notifications.CancelAllCountdowns()
    for _, notif in ipairs(activeNotifications) do
        if notif.ticker then
            notif.ticker:Cancel()
        end
        if notif.frame then
            notif.frame:Reset()
            QRA.Notifications.UI.ReleaseFrame(notif.frame)
        end
    end

    wipe(activeNotifications)
    QRA.Notifications.ClearTTSQueue()

    QRA.Debug("Notifications: Cancelled all countdowns")
end

--- Get the count of active notifications
---@return number
function QRA.Notifications.GetActiveCount()
    return #activeNotifications
end

--------------------------------------------------
-- Chat Messages
--------------------------------------------------

--- Send a message to chat
---@param message string The message to send
---@param channel string|nil Chat channel (SAY, PARTY, RAID, etc.)
function QRA.Notifications.SendChat(message, channel)
    if not config.chatEnabled then return end

    channel = channel or config.chatChannel

    -- Determine appropriate channel
    if channel == "RAID" and not IsInRaid() then
        if IsInGroup() then
            channel = "PARTY"
        else
            channel = "SAY"
        end
    elseif channel == "PARTY" and not IsInGroup() then
        channel = "SAY"
    end

    C_ChatInfo.SendChatMessage(message, channel)
    QRA.Debug("Notifications: Chat -", channel, message)
end

--------------------------------------------------
-- Raid Warning
--------------------------------------------------

--- Show a raid warning style message
---@param message string The message to display
---@param playSound boolean|nil Whether to play the raid warning sound
function QRA.Notifications.ShowRaidWarning(message, playSound)
    if RaidNotice_AddMessage then
        RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
    end

    if playSound then
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end
end

--------------------------------------------------
-- Configuration
--------------------------------------------------

--- Get current notification settings
---@return QRA_NotificationConfig
function QRA.Notifications.GetConfig()
    return config
end

--- Update notification settings
---@param settings QRA_NotificationConfig
function QRA.Notifications.SetConfig(settings)
    for key, value in pairs(settings) do
        if config[key] ~= nil then
            config[key] = value
        end
    end
end

--- Enable/disable TTS
---@param enabled boolean
function QRA.Notifications.SetTTSEnabled(enabled)
    config.ttsEnabled = enabled
end

--- Enable/disable sound
---@param enabled boolean
function QRA.Notifications.SetSoundEnabled(enabled)
    config.soundEnabled = enabled
end

--- Enable/disable screen messages
---@param enabled boolean
function QRA.Notifications.SetScreenEnabled(enabled)
    config.screenEnabled = enabled
end

--- Enable/disable chat messages
---@param enabled boolean
function QRA.Notifications.SetChatEnabled(enabled)
    config.chatEnabled = enabled
end

--------------------------------------------------
-- Test Functions
--------------------------------------------------

--- Test TTS notification
function QRA.Notifications.TestTTS()
    QRA.Notifications.SpeakTTS("This is a test of the text to speech system")
end

--- Test sound notification
function QRA.Notifications.TestSound()
    QRA.Notifications.PlaySound()
end

--- Test screen notification
function QRA.Notifications.TestScreen()
    QRA.Notifications.ShowOnScreen("Test Screen Message", 3, {1, 1, 0})
end

--- Test countdown
function QRA.Notifications.TestCountdown()
    local assignment = {
        message = "Use Heroism",
        countdownTime = 5,
    }
    QRA.Notifications.ShowCountdown(assignment, 5)
end

--- Test multiple simultaneous countdowns
function QRA.Notifications.TestMultipleCountdowns()
    -- First assignment with 5 second countdown
    local assignment1 = {
        message = "Use Heroism",
        spellName = "Heroism",
        countdownTime = 5,
    }
    QRA.Notifications.ShowCountdown(assignment1, 5)

    -- Second assignment with 3 second countdown (should get audio priority)
    C_Timer.After(2, function()
        local assignment2 = {
            message = "Use Power Infusion",
            spellName = "Power Infusion",
            countdownTime = 5,
        }
        QRA.Notifications.ShowCountdown(assignment2, 5)
    end)
end

--------------------------------------------------
-- Persistence
--------------------------------------------------

--- Save notification settings to DB
function QRA.Notifications.SaveToDB()
    if not QRA.DB then return end
    QRA.DB.notifications = {
        ttsEnabled = config.ttsEnabled,
        soundEnabled = config.soundEnabled,
        screenEnabled = config.screenEnabled,
        chatEnabled = config.chatEnabled,
        screenDuration = config.screenDuration,
        chatChannel = config.chatChannel,
        framePosition = config.framePosition,
    }
end

--- Load notification settings from DB
function QRA.Notifications.LoadFromDB()
    if not QRA.DB or not QRA.DB.notifications then return end

    for key, value in pairs(QRA.DB.notifications) do
        if config[key] then
            config[key] = value
        end
    end
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function QRA.Notifications.Initialize()
    QRA.Notifications.LoadFromDB()

    QRA.Notifications.UI.InitializeFramePool(config.framePosition)

    moverReferenceFrame = QRA.Notifications.UI.CreateMoverReferenceFrame(config.framePosition)
    moverReferenceFrame:Show()
    AF.CreateMover(moverReferenceFrame, MOVER_GROUP, "Notification Frame", UpdateFramePosition)
    moverReferenceFrame:Hide()

    QRA.Debug("Notifications: Module initialized with frame pool")
end
