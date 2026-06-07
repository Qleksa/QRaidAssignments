---@class QRA
local QRA = select(2, ...)

QRA.UI.ContextMenus = {}

--- Show context menu for a trigger
---@param owner Region
---@param trigger Trigger
---@param onDelete fun(trigger: Trigger)
---@param onAddAssignment fun(triggerId: string)
function QRA.UI.ContextMenus.ShowTriggerContextMenu(owner, trigger, onDelete, onAddAssignment)
    local menuItems = {
        {
            QRA.L["Add Assignment"],
            function()
                if onAddAssignment then onAddAssignment(trigger.id) end
            end,
        },
        {
            QRA.L["Export"],
            function()
                local exportString = QRA.Comm.ExportTrigger(trigger.id)
                QRA.UI.Dialogs.ShowExportFrame(exportString)
            end,
        },
        {
            QRA.L["Send to Raid"],
            function()
                local exportString = QRA.Comm.ExportActiveSharedPlan(true)
                QRA.Comm.SendToRaid(exportString)
            end,
        },
    }

    if not trigger.default then
        table.insert(menuItems, {
            QRA.L["Delete Trigger"],
            function()
                if onDelete then onDelete(trigger) end
            end,
        })
    end

    MenuUtil.CreateButtonContextMenu(owner, unpack(menuItems))
end

--- Show context menu for an assignment
---@param owner Region
---@param assignment Assignment
---@param triggerId string
---@param onDelete fun(assignment: Assignment, triggerId: string)
function QRA.UI.ContextMenus.ShowAssignmentContextMenu(owner, assignment, triggerId, onDelete)
    MenuUtil.CreateButtonContextMenu(owner,
        {
            QRA.L["Delete Assignment"],
            function()
                if onDelete then onDelete(assignment, triggerId) end
            end,
        }
    )
end

--- Show context menu for an orphaned assignment
---@param owner Region
---@param assignment Assignment
---@param onDelete fun(assignment: Assignment)
---@param onAdopt fun(assignment: Assignment)
function QRA.UI.ContextMenus.ShowOrphanedAssignmentContextMenu(owner, assignment, onDelete, onAdopt)
    MenuUtil.CreateButtonContextMenu(owner,
        {
            QRA.L["Assign to Trigger"],
            function()
                if onAdopt then onAdopt(assignment) end
            end,
        },
        {
            QRA.L["Delete Assignment"],
            function()
                if onDelete then onDelete(assignment) end
            end,
        }
    )
end
