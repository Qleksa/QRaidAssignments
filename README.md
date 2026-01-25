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

Each trigger has counters, allowing you to specify which occurrence should activate an assignment (e.g., "trigger on the 3rd cast").

### Assignment System
Create assignments that link to triggers:
- Specify a spell to use
- Set a countdown timer for the alert
- Choose alert type (TTS, sound, on-screen, or chat)
- Configure which trigger occurrence activates the assignment

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

### Settings

Configure notification preferences in the **Settings** tab:
- Enable/disable TTS
- Enable/disable sounds
- Enable/disable on-screen messages
- Enable/disable chat messages
- Test each notification type

## Dependencies

- **AbstractFramework** (required) - UI framework

## Contributing

Contributions are welcome! Please submit issues and pull requests.

## License

This addon is released under the GPL 3 License.

## Author

Created by Qleksa
