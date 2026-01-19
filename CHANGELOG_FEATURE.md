# Changelog Window Feature

## Overview
The changelog window displays automatically on the first login after a new major or minor version update. This helps users stay informed about new features and improvements.

## How It Works

### Automatic Display
- Triggers on **major** or **minor** version changes (e.g., 0.5.0 → 0.6.0 or 1.0.0 → 2.0.0)
- Does NOT trigger on **patch** version changes (e.g., 0.6.0 → 0.6.1)
- Appears 1.5 seconds after login to allow UI to settle
- Displays centered on screen with scrollable content

### User Controls
- **Checkbox**: "Don't show until next version"
  - When checked, changelog won't appear again until the next version update
  - Resets automatically when a new version is detected
- **Close Button**: Dismisses the window and saves the current version as seen

### Version Tracking
The addon saves two settings in `QRA_DB.settings`:
- `lastSeenVersion`: The last version the user saw the changelog for
- `hideChangelogUntilNextVersion`: User preference to suppress changelog

## Updating Changelog Content

### Location
Edit `Changelog.lua` and update the `CHANGELOG_DATA` table:

```lua
local CHANGELOG_DATA = {
    {
        version = "0.7.0",
        changes = {
            "Added new trigger type for boss phases",
            "Fixed countdown accuracy issues",
            "Improved error messages",
        }
    },
    {
        version = "0.6.0",
        changes = {
            "Added changelog window",
            "Improved version tracking",
        }
    },
}
```

### Best Practices
1. **Add new versions at the top** of the `CHANGELOG_DATA` table
2. **Keep entries concise** - focus on user-visible changes
3. **Use clear language** - avoid technical jargon
4. **Group by type** if there are many changes (Features, Fixes, etc.)
5. **Update before tagging** a new release

### Format Guidelines
- Start each change with a dash (`-`)
- Use present tense or past tense consistently
- Be specific but brief
- Highlight breaking changes or important updates

## Manual Testing

### Slash Command
Use `/qra changelog` to manually open the changelog window at any time, regardless of version state.

### Debug Commands
Enable debug mode to see version checking logs:
```
/qra debug
```

Test version changes by manipulating saved variables:
```
/run QRA.DB.settings.lastSeenVersion = "0.5.0"
/reload
```

## Development Builds
Development builds using `@project-version@` placeholder are assigned version `999.999.999` to ensure they always show as newer than released versions.

## Future Enhancements

### Potential Automation
The issue mentions possible automation using BigWigs packager workflow. Options include:

1. **Git Commit Parsing**: Extract changelog from git log
2. **CHANGELOG.md File**: Maintain a markdown file and parse it
3. **GitHub Actions**: Automate injection before release

For now, manual updates are recommended for full control over content and formatting.

### Implementation Ideas
If automation is desired, create a GitHub Actions workflow that:
1. Extracts recent changes (commits or from CHANGELOG.md)
2. Formats them into Lua table structure
3. Updates `Changelog.lua` using sed/awk
4. Commits the change before running packager

See `.github/workflows/release.yml` for current release workflow.

## Troubleshooting

### Changelog Not Appearing
1. Check debug mode: `/qra debug`
2. Verify version change: Compare `lastSeenVersion` with current `QRA.version`
3. Check if hiding: `hideChangelogUntilNextVersion` should be `false` for new versions
4. Ensure module loaded: Check for errors in chat on login

### Testing Without Version Change
Use the manual command:
```
/qra changelog
```

### Reset Version Tracking
To force changelog to appear again:
```
/run QRA.DB.settings.lastSeenVersion = "0.0.0"
/run QRA.DB.settings.hideChangelogUntilNextVersion = false
/reload
```

## Technical Details

### Version Parsing
Versions are parsed into major.minor.patch format:
- "1.2.3" → major=1, minor=2, patch=3
- "0.6.0" → major=0, minor=6, patch=0

Changelog triggers when:
- `currentMajor > lastMajor` OR
- `currentMajor == lastMajor AND currentMinor > lastMinor`

### Module Initialization
1. `Changelog.lua` loads via TOC file
2. `QRA.Changelog.Initialize()` called during module initialization
3. `QRA.Changelog.CheckAndShow()` called after PLAYER_LOGIN
4. Version check happens, window shows if needed

### UI Framework
Uses AbstractFramework components:
- `AF.CreateHeaderedFrame()` for main window
- `AF.CreateCheckBox()` for user preference
- `AF.CreateButton()` for close button
- Standard ScrollFrame for content

## Files Modified
- `Changelog.lua` - Main module (NEW)
- `Core/Main.lua` - Integration and initialization
- `Init.lua` - Module declaration
- `QRaidAssignments.toc` - Load order
- `locales/enUS.lua` - Localized strings
