# Q's Raid Assignments

A World of Warcraft Classic addon for managing raid assignments with customizable triggers and alerts.

## Features

### Trigger System
Create triggers based on various in-game events:
- **Spell Cast Success** - Triggers when a specific spell completes casting
- **Spell Cast Start** - Triggers when a spell begins casting
- **Aura Applied** - Triggers when a buff/debuff is applied
- **Aura Removed** - Triggers when a buff/debuff is removed
- **Timer** - Triggers at a specific time after encounter start
- **NPC Death** - Triggers when a specific NPC dies

Each trigger tracks occurrences, allowing you to specify which occurrence should activate an assignment (e.g., "trigger on the 3rd cast").

### Assignment System
Create assignments that link to triggers:
- Specify a spell to use
- Set a countdown timer for the alert
- Choose alert type (TTS, sound, on-screen, or chat)
- Configure which trigger occurrence activates the assignment

### Templates
Save your trigger/assignment configurations as templates:
- Reuse configurations across different encounters
- Share templates with your raid team (export/import)
- Quick-apply templates for common scenarios

### Notification Types
- **Text-to-Speech (TTS)** - Speak the alert message
- **Sound** - Play custom or default sounds
- **On-Screen Text** - Display large centered text
- **Chat Message** - Send to party/raid chat
- **Countdown Alerts** - 3-2-1 countdown before action

## Installation

1. Download the addon
2. Extract to `Interface/AddOns/QRaidAssignments`
3. Requires [AbstractFramework](https://github.com/enderneko/AbstractFramework)

## Usage

### Slash Commands
- `/qra` or `/qraid` - Toggle the main window
- `/qra show` - Show the main window
- `/qra hide` - Hide the main window
- `/qra test` - Test countdown notifications
- `/qra debug` - Toggle debug mode
- `/qra help` - Show available commands

### Creating an Assignment

1. Open the addon with `/qra`
2. Go to the **Triggers** tab
3. Click **+ Add Trigger** and configure:
   - Select trigger type (e.g., "Spell Cast Start")
   - Enter the spell ID
   - Set which occurrence to trigger on
4. Go to the **Assignments** tab
5. Click **+ Add Assignment** and configure:
   - Enter the spell to use (optional)
   - Set countdown time before alert
   - Choose alert type
6. Link the assignment to your trigger

### Saving Templates

1. Configure your triggers and assignments
2. Go to the **Templates** tab
3. Click **Save Current as Template**
4. Enter a name for the template

### Settings

Configure notification preferences in the **Settings** tab:
- Enable/disable TTS
- Enable/disable sounds
- Enable/disable on-screen messages
- Enable/disable chat messages
- Test each notification type

## File Structure

```
QRaidAssignments/
├── core/
│   ├── main.lua           # Main addon initialization
│   ├── triggers.lua       # Trigger system
│   ├── assignments.lua    # Assignment management
│   └── templates.lua      # Template save/load
├── ui/
│   ├── mainUI.lua         # Main UI layout
│   ├── widgets.lua        # Custom widget definitions
│   └── notifications.lua  # Alert system
├── locales/
│   └── enUS.lua           # Localization strings
├── Media/
│   └── Sounds/            # Custom sound files
├── QRaidAssignments.toc   # Addon metadata
└── README.md              # This file
```

## Dependencies

- **AbstractFramework** (required) - UI framework
- **LibDeflate** (optional) - For template import/export
- **AceSerializer-3.0** (optional) - For template serialization

## API

The addon exposes several APIs for integration:

```lua
-- Triggers
QRA.Triggers.Create(type, config)  -- Create a new trigger
QRA.Triggers.Register(trigger)      -- Register a trigger
QRA.Triggers.Unregister(id)         -- Unregister a trigger
QRA.Triggers.GetAll()               -- Get all triggers

-- Assignments
QRA.Assignments.Create(config)      -- Create an assignment
QRA.Assignments.Add(assignment)     -- Add an assignment
QRA.Assignments.Remove(id)          -- Remove an assignment
QRA.Assignments.GetAll()            -- Get all assignments

-- Templates
QRA.Templates.Create(name)          -- Create a template
QRA.Templates.Save(template)        -- Save a template
QRA.Templates.Apply(id)             -- Apply a template
QRA.Templates.Export(id)            -- Export to string
QRA.Templates.Import(string)        -- Import from string

-- Notifications
QRA.Notifications.SpeakTTS(msg)     -- TTS alert
QRA.Notifications.PlaySound(file)   -- Sound alert
QRA.Notifications.ShowOnScreen(msg) -- Screen alert
QRA.Notifications.SendChat(msg)     -- Chat alert
```

## Contributing

Contributions are welcome! Please submit issues and pull requests.

## License

This addon is released under the MIT License.

## Author

Created by Qleksa
