
---@class QRA
QRA = {}

---@class LibSerialize
---@field SerializeEx fun(self: LibSerialize, options: table, input: any): string
---@field Deserialize fun(self: LibSerialize, input: string): boolean, table

local areLibsOkay = true
do
    local standaloneLibs = {
        "LibStub"
    }
    local libStubLibs = {
        "Ace-Comm-3.0",
        "LibSerialize",
        "LibDeflate",
    }

    for _, lib in ipairs(standaloneLibs) do
        if not lib then
            areLibsOkay = false
            QRA.Print("Missing library:", lib)
        end
    end
    if LibStub then
        for _, lib in ipairs(libStubLibs) do
            if not LibStub:GetLibrary(lib, true) then
                areLibsOkay = false
                QRA.Print("Missing library:", lib)
            end
        end
    else
        areLibsOkay = false
        QRA.Print("Missing library: LibStub")
    end
end

function QRA.AreLibsOkay()
    return areLibsOkay
end
