---@class QRA
local QRA = select(2, ...)

local AF = _G.AbstractFramework

---@class Logger
QRA.Logger = QRA.Logger or {}
local Logger = QRA.Logger ---@class Logger

---@class QRA_LogsFrame : AF_HeaderedFrame
local frame = nil

local function CreateFrame()
    if frame then return end

    frame = AF.CreateHeaderedFrame(QRA.UIParent, "QRA_LogUIFrame", "QRA Logs", 600, 400)
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("CENTER")
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    frame:Hide()

    local scrollFrame = AF.CreateScrollFrame(frame, "QRA_LogUIScrollFrame", 590, 365)
    scrollFrame:SetPoint("TOPLEFT", 5, -5)

    local logEditBox = AF.CreateScrollEditBox(scrollFrame.scrollContent, "QRA_LogUIEditBox", nil, 580, 355)
    logEditBox:SetPoint("TOPLEFT", scrollFrame.scrollContent, "TOPLEFT", 5, -5)
    logEditBox:SetPoint("TOPRIGHT", scrollFrame.scrollContent, "TOPRIGHT", -5, -5)
    logEditBox:SetText(unpack(QRA.Logger.GetLogs()))

    local clearBtn = AF.CreateButton(frame, "Clear logs", "white", 100, 25)
    clearBtn:SetPoint("BOTTOMRIGHT", -6, 4)
    clearBtn:SetScript("OnClick", function()
        QRA.Logger.ClearLogs()
        frame:UpdateLogText()
    end)

    function frame:UpdateLogText()
        logEditBox:SetText(table.concat(QRA.Logger.GetLogs(), "\n"))
    end
end

function QRA.Logger.ToggleLogFrame()
    if not frame then
        CreateFrame()
    end

    if frame:IsShown() then
        frame:Hide()
    else
        frame:UpdateLogText()
        frame:Show()
    end
end
