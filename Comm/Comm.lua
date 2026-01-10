---@class QRA
local QRA = QRA

QRA.Comm = {}

local LibSerialize = LibStub:GetLibrary("LibSerialize")
local LibDeflate = LibStub:GetLibrary("LibDeflate")

function QRA.Comm.Export()
    QRA.Debug("Comm: Exporting Data")
    -- Export all triggers and assignments
end

---@param boss number encounter id
---@return string
function QRA.Comm.ExportBoss(boss)
    QRA.Debug("Comm: Exporting Boss Data")
    local bossData = type(boss) == "number" and QRA.Bosses.GetBossByEncounterId(boss) or QRA.Bosses.GetBossByName(boss)
    if bossData then
        -- Export specific boss triggers and assignments
        local serialized = LibSerialize:SerializeEx({}, bossData)
        local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
        local encoded = "!QRA!" .. LibDeflate:EncodeForPrint(compressed)
        QRA.Debug("Comm: Exported Boss Data:", encoded)
        QRA.Comm.exportedBoss = encoded
    else
        QRA.Debug("Comm: Boss not found:", boss)
    end
end

function QRA.Comm.Import(input)
    QRA.Debug("Comm: Importing Data")
    local _, _, encoded = input:find("^!QRA!(.+)$")

    if not encoded then
        QRA.Debug("Comm: Invalid import string")
        return
    end

    local decoded = LibDeflate:DecodeForPrint(encoded)
    if not decoded then
        QRA.Print("Comm: Failed to decode import string")
        return
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        QRA.Print("Comm: Failed to decompress import string")
        return
    end
    local success, deserialized = LibSerialize:Deserialize(decompressed)
    if success then
        QRA.Debug("Comm: Deserialized Data:", deserialized)
        -- Handle imported data
    else
        QRA.Print("Comm: Failed to deserialize data")
    end
end

local function TestImportExport()
    QRA.Debug("Comm: Testing Import/Export")
    QRA.Comm.ExportBoss(1443)
    QRA.Comm.Import(QRA.Comm.exportedBoss)
end

function QRA.Comm.Initialize()
    QRA.Debug("Comm: Module Initialized")

    if QRA.Settings.debug then
        TestImportExport()
    end
end
