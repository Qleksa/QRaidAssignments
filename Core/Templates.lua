--[[
    QRaidAssignments - Template System
    Allows saving and loading trigger/assignment configurations as templates
    Templates can be shared between encounters or exported/imported
]]

local QRA = _G.QRA
QRA.Templates = {}

--------------------------------------------------
-- State Management
--------------------------------------------------
local templates = {}  -- All saved templates

--------------------------------------------------
-- Helper Functions
--------------------------------------------------

--- Generate a unique ID for a template
---@return string
local function GenerateTemplateID()
    return string.format("tmpl_%s_%s", time(), math.random(1000, 9999))
end

--- Deep copy a table
---@param orig table
---@return table
local function DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for key, value in pairs(orig) do
            copy[DeepCopy(key)] = DeepCopy(value)
        end
    else
        copy = orig
    end
    return copy
end

--------------------------------------------------
-- Template Creation
--------------------------------------------------

--- Create a new template from current trigger/assignment setup
---@param name string Template name
---@param description string|nil Optional description
---@param encounterId number|nil Optional encounter ID to associate
---@return table template The created template
function QRA.Templates.Create(name, description, encounterId)
    local template = {
        id = GenerateTemplateID(),
        name = name or "Unnamed Template",
        description = description or "",
        encounterId = encounterId,
        encounterName = nil,  -- Will be set if encounterId provided

        triggers = {},
        assignments = {},

        createdAt = time(),
        modifiedAt = time(),
        version = 1,
    }

    -- Get encounter name if ID provided
    if encounterId then
        -- In Classic, we might need to use our own encounter database
        template.encounterName = QRA.Encounters and QRA.Encounters.GetName(encounterId) or "Unknown"
    end

    return template
end

--- Create a template from existing triggers and assignments
---@param name string Template name
---@param triggerIds table List of trigger IDs to include
---@param assignmentIds table|nil List of assignment IDs (if nil, includes all linked)
---@return table template
function QRA.Templates.CreateFromCurrent(name, triggerIds, assignmentIds)
    local template = QRA.Templates.Create(name)

    -- Copy selected triggers
    for _, triggerId in ipairs(triggerIds or {}) do
        local trigger = QRA.Triggers.Get(triggerId)
        if trigger then
            table.insert(template.triggers, DeepCopy(trigger))
        end
    end

    -- Copy assignments (either specified or all linked to included triggers)
    if assignmentIds then
        for _, assignmentId in ipairs(assignmentIds) do
            local assignment = QRA.Assignments.Get(assignmentId)
            if assignment then
                table.insert(template.assignments, DeepCopy(assignment))
            end
        end
    else
        -- Get all assignments linked to the included triggers
        local allAssignments = QRA.Assignments.GetAll()
        for id, assignment in pairs(allAssignments) do
            for _, trigger in ipairs(template.triggers) do
                if assignment.triggerId == trigger.id then
                    table.insert(template.assignments, DeepCopy(assignment))
                    break
                end
            end
        end
    end

    return template
end

--------------------------------------------------
-- Template Management
--------------------------------------------------

--- Save a template
---@param template table The template to save
function QRA.Templates.Save(template)
    if not template or not template.id then
        QRA.Debug("Templates: Invalid template")
        return false
    end

    template.modifiedAt = time()
    templates[template.id] = template

    QRA.Templates.SaveToDB()
    QRA.Debug("Templates: Saved", template.name)
    return true
end

--- Delete a template
---@param templateId string The template ID to delete
function QRA.Templates.Delete(templateId)
    if templates[templateId] then
        local name = templates[templateId].name
        templates[templateId] = nil
        QRA.Templates.SaveToDB()
        QRA.Debug("Templates: Deleted", name)
        return true
    end
    return false
end

--- Get a template by ID
---@param templateId string
---@return table|nil
function QRA.Templates.Get(templateId)
    return templates[templateId]
end

--- Get all templates
---@return table
function QRA.Templates.GetAll()
    return templates
end

--- Get templates as an ordered list
---@return table
function QRA.Templates.GetAsList()
    local list = {}
    for id, template in pairs(templates) do
        table.insert(list, template)
    end
    -- Sort by name
    table.sort(list, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return list
end

--- Get templates for a specific encounter
---@param encounterId number
---@return table
function QRA.Templates.GetForEncounter(encounterId)
    local result = {}
    for id, template in pairs(templates) do
        if template.encounterId == encounterId then
            table.insert(result, template)
        end
    end
    return result
end

--- Rename a template
---@param templateId string
---@param newName string
function QRA.Templates.Rename(templateId, newName)
    local template = templates[templateId]
    if template then
        template.name = newName
        template.modifiedAt = time()
        QRA.Templates.SaveToDB()
        return true
    end
    return false
end

--------------------------------------------------
-- Template Application
--------------------------------------------------

--- Apply a template, loading its triggers and assignments
---@param templateId string The template to apply
---@param clearExisting boolean|nil Clear existing triggers/assignments first
function QRA.Templates.Apply(templateId, clearExisting)
    local template = templates[templateId]
    if not template then
        QRA.Debug("Templates: Template not found", templateId)
        return false
    end

    if clearExisting then
        QRA.Triggers.UnregisterAll()
        -- Clear assignments would go here
    end

    -- Create mapping from old trigger IDs to new ones
    local triggerIdMap = {}

    -- Register triggers from template
    for _, triggerData in ipairs(template.triggers) do
        local newTrigger = DeepCopy(triggerData)
        local oldId = newTrigger.id

        -- Generate new ID to avoid conflicts
        newTrigger.id = nil
        newTrigger = QRA.Triggers.Create(newTrigger.type, newTrigger)

        triggerIdMap[oldId] = newTrigger.id
        QRA.Triggers.Register(newTrigger)
    end

    -- Create assignments from template, updating trigger references
    for _, assignmentData in ipairs(template.assignments) do
        local newAssignment = DeepCopy(assignmentData)

        -- Update trigger ID reference
        if newAssignment.triggerId and triggerIdMap[newAssignment.triggerId] then
            newAssignment.triggerId = triggerIdMap[newAssignment.triggerId]
        end

        newAssignment.id = nil  -- Will be regenerated
        newAssignment = QRA.Assignments.Create(newAssignment)
        QRA.Assignments.Add(newAssignment)
    end

    QRA.Debug("Templates: Applied", template.name)
    return true
end

--------------------------------------------------
-- Import/Export
--------------------------------------------------

--- Export a template to a string (for sharing)
---@param templateId string
---@return string|nil
function QRA.Templates.Export(templateId)
    local template = templates[templateId]
    if not template then return nil end

    -- Create export data
    local exportData = {
        version = 1,
        addon = "QRaidAssignments",
        template = DeepCopy(template),
    }

    -- Serialize and encode
    local serialized = QRA.Serialize(exportData)
    if serialized then
        local compressed = LibStub("LibDeflate"):CompressDeflate(serialized)
        local encoded = LibStub("LibDeflate"):EncodeForPrint(compressed)
        return encoded
    end

    return nil
end

--- Import a template from an export string
---@param importString string
---@return table|nil template The imported template, or nil on failure
---@return string|nil error Error message if failed
function QRA.Templates.Import(importString)
    if not importString or importString == "" then
        return nil, "Empty import string"
    end

    local LibDeflate = LibStub("LibDeflate", true)
    if not LibDeflate then
        return nil, "LibDeflate not available"
    end

    -- Decode and decompress
    local decoded = LibDeflate:DecodeForPrint(importString)
    if not decoded then
        return nil, "Failed to decode import string"
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        return nil, "Failed to decompress import data"
    end

    -- Deserialize
    local success, importData = QRA.Deserialize(decompressed)
    if not success or not importData then
        return nil, "Failed to deserialize import data"
    end

    -- Validate
    if importData.addon ~= "QRaidAssignments" then
        return nil, "Invalid template format"
    end

    if not importData.template then
        return nil, "No template data found"
    end

    -- Generate new ID for imported template
    local template = importData.template
    template.id = GenerateTemplateID()
    template.name = template.name .. " (Imported)"
    template.modifiedAt = time()

    return template, nil
end

--------------------------------------------------
-- Persistence
--------------------------------------------------

--- Save templates to the database
function QRA.Templates.SaveToDB()
    if not QRA.DB then return end
    QRA.DB.templates = {}

    for id, template in pairs(templates) do
        QRA.DB.templates[id] = template
    end

    QRA.Debug("Templates: Saved to DB")
end

--- Load templates from the database
function QRA.Templates.LoadFromDB()
    if not QRA.DB or not QRA.DB.templates then return end

    wipe(templates)
    for id, template in pairs(QRA.DB.templates) do
        templates[id] = template
    end

    QRA.Debug("Templates: Loaded", QRA.TableCount(templates), "from DB")
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function QRA.Templates.Initialize()
    QRA.Templates.LoadFromDB()
    QRA.Debug("Templates: Module initialized")
end
