---@type string
local AddonName = ...
---@class Private
local Private = select(2, ...)

---@class QRA
QRA = {}

---@class Private

---@class LibSerialize
---@field SerializeEx fun(self: LibSerialize, options: table, input: any): string
---@field Deserialize fun(self: LibSerialize, input: string): boolean, table
