# QRaidAssignments - Copilot Instructions

## Project Overview
World of Warcraft Classic addon for managing raid assignments with event-driven triggers and customizable alerts. Built on AbstractFramework, uses LuaDoc annotations extensively.

## Architecture

### Module Structure
The addon uses a global namespace pattern with module separation:
- **`QRA`** - Global namespace containing all modules (see [Init.lua](../Init.lua))
- **Core modules** - Pre-initialized as empty tables in Init.lua, populated in separate files
- **Dependency order** - Modules initialize in sequence via `QRA.InitializeModules()` in [Core/Main.lua](../Core/Main.lua)

### Key Components
1. **Triggers** ([Core/Triggers.lua](../Core/Triggers.lua)) - Event-driven system tracking combat log events, timers, HP thresholds
2. **Assignments** ([Core/Assignments.lua](../Core/Assignments.lua)) - Links to triggers, manages countdowns and alerts
3. **Counter Formula** ([Util/CounterFormula.lua](../Util/CounterFormula.lua)) - Parses expressions like `"1,3,5"`, `">2,+<6"`, `"1%3"` to determine which trigger occurrences fire
4. **DevMode** ([DevMode/](../DevMode/)) - Full testing environment with fake encounters, event firing, and event history

### Critical Dependencies
- **AbstractFramework** (required) - Provides `AF.RegisterAddon`, `AF.Print`, `AF.Serialize`, UI widgets
- Loaded from global `_G.AbstractFramework`
- APIs aliased in Init.lua: `QRA.Print`, `QRA.Serialize`, `QRA.RegisterComm`, etc.
- Check `QRA.AreLibsOkay()` before using LibStub libraries (AceComm, LibSerialize, LibDeflate)

## Code Patterns

### LuaDoc Type Annotations
All major data structures are typed with LuaDoc (see [Init.lua](../Init.lua#L42-L89)):
```lua
---@class Trigger
---@field id string
---@field type string
---@field counterFormula string
---@field assignments Assignment[]

---@class Assignment
---@field triggerId string
---@field counterFormula string
---@field alertType AlertType
```
**Always add annotations for new classes, functions, and parameters.**

### Event Handling Pattern
Events use frame script handlers with method dispatch:
```lua
frame:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)
frame:RegisterEvent("ENCOUNTER_START")
function frame:ENCOUNTER_START(encounterId, encounterName, ...)
    -- Handle event
end
```

### Module Pattern
Each module follows this structure:
```lua
---@class QRA
local QRA = select(2, ...)
QRA.ModuleName = {}

-- State (local)
local privateData = {}

-- Public API
function QRA.ModuleName.Initialize()
    -- Setup
end

-- Private helpers (local functions)
local function helper() end
```

### Data Persistence
- **SavedVariables**: `QRA_DB` declared in [QRaidAssignments.toc](../QRaidAssignments.toc)
- **Aliased**: `QRA.DB = QRA_DB` after PLAYER_LOGIN
- **Structure**: `{ assignments={}, triggers={}, templates={}, notifications={}, settings={}, devMode={} }`
- **Persistence calls**: Always call `QRA.Triggers.SaveToDB()` or `QRA.Assignments.SaveToDB()` after mutations

## Development Workflow

### Testing
- **DevMode**: Use `/qra test` to enable test mode with fake encounters
- **Test Panel**: [DevMode/UI/TestPanel.lua](../DevMode/UI/TestPanel.lua) - Fire custom events
- **Fake Boss**: [DevMode/UI/FakeBossUI.lua](../DevMode/UI/FakeBossUI.lua) - Simulate boss encounters
- **Event History**: All combat log events logged when DevMode enabled

### Debugging
- **Debug messages**: Use `QRA.Debug("message", var1, var2)` from [Util/Debug.lua](../Util/Debug.lua)
- Toggle with `/qra debug` or `QRA.Settings.debug = true`
- Prefixes all messages with module context

### File Loading Order
Files load in **exact order** specified in [QRaidAssignments.toc](../QRaidAssignments.toc). When adding files:
1. Add to TOC in dependency order
2. Utilities before Core, Core before UI
3. DevMode loads last

## Communication System
- **Export/Import**: [Comm/Comm.lua](../Comm/Comm.lua) handles serialization of triggers + assignments
- **Addon messages**: Uses AceComm-3.0 via `QRA.RegisterComm("QRA_COMM", callback)`
- **Bulk transfer**: `QRA.SendCommMessage()` with callback for progress tracking
- Check `QRA.AreLibsOkay()` before using comm features

## Counter Formula Syntax
Critical for triggers and assignments - determines which occurrences fire:
- `*` - All
- `5` - Only 5th
- `!4` - All except 4th
- `1-5` - Range
- `<3`, `>2`, `<=3`, `>=2` - Comparisons
- `1%3` - Modulo (1st, 4th, 7th...)
- `1,3,5` - OR logic
- `>3,+<7` - AND logic (prefix `+` after comma)

Parse with `QRA.CounterFormula.Matches(formula, counter)`

## Assignment Targeting System
Assignments can target specific players via flexible target strings ([Assignments/Core/AssignTarget.lua](../Assignments/Core/AssignTarget.lua)):
- **Role-based**: `"TANK"`, `"HEALER"`, `"DPS"` (all players in role)
- **Role with index**: `"TANK1"`, `"HEALER2"` (1st tank, 2nd healer)
- **Spec-based**: `"HPAL"`, `"FDRUID"` (all holy paladins, all feral druids)
- **Spec with index**: `"HPAL1"`, `"PRIST2"` (1st holy paladin, 2nd priest)
- **Class-based**: `"WARR"`, `"MAGE"` (all warriors, all mages)
- **Specific player**: `"Playername"` (exact player name)
- **Everyone**: `"ALL"` (entire raid)

Specification data in [Assignments/Data/classSpecs.lua](../Assignments/Data/classSpecs.lua) maps abbreviations to classes/specs.

## Naming Conventions
- **Global frames**: `QRA_*` prefix (e.g., `QRA_Parent`, `QRA_TriggerFrame`)
- **Function names**: PascalCase for public APIs, camelCase for local helpers
- **Constants**: SCREAMING_SNAKE_CASE in module tables (e.g., `QRA.Triggers.Types.SPELL_CAST_SUCCESS`)
- **IDs**: Generated with timestamp + random suffix (e.g., `"trigger_1234567890_5432"`)

## Localization
Currently English-only via [locales/enUS.lua](../locales//enUS.lua). All UI strings referenced through `QRA.L["key"]` table. Future localization support planned - add new locale files following enUS structure.

## UI Framework
Uses AbstractFramework widgets:
- **Most common widgets** in codebase:
  - `AF.CreateDropdown()` - For selector menus (alert types, bosses)
  - `AF.CreateEditBox()` - For text input (spell IDs, formulas, thresholds)
  - `AF.CreateSlider()` - For numeric input (countdown seconds)
  - `AF.CreateCascadingMenuButton()` - For hierarchical menus (spells, triggers)
- Custom widgets in [UI/Widgets.lua](../UI/Widgets.lua):
  - `QRA.Widgets.CreateSpellInput()` - Spell picker with icon and menu
  - `QRA.Widgets.CreateCounterInput()` - Counter formula input with validation
  - `QRA.Widgets.CreateTriggerTypeDropdown()` - Trigger type selector
  - `QRA.Widgets.CreateAlertTypeDropdown()` - Alert notification type picker
- Main UI in [UI/Main.lua](../UI/Main.lua) - Tabbed interface pattern (Triggers, Assignments, Settings)
- Color scheme: Use `AF.GetColorRGB("accent")` for active states, `AF.GetColorRGB("gray")` for inactive
