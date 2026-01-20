# Automated Changelog Generation

## Overview

The changelog is automatically generated and injected into `Changelog.lua` when a new version tag is pushed. This automation uses GitHub Actions to extract commit messages and update the changelog data structure.

## How It Works

### Workflow Trigger
When you push a version tag (e.g., `v0.7.0`), the GitHub Actions workflow automatically:

1. **Extracts version** from the tag name (v0.7.0 → 0.7.0)
2. **Generates changelog** from git commits since the last tag
3. **Updates Changelog.lua** with the new version entry
4. **Commits changes** back to the repository
5. **Updates the tag** to point to the new commit
6. **Packages and releases** using BigWigs packager

### Commit Message Filtering

The workflow filters out certain commit types:
- Merge commits
- WIP commits
- "Update" commits (generic updates)
- "Initial plan" commits
- "Fix typo" commits

This ensures only meaningful changes appear in the changelog.

## Release Process

### Manual Steps

1. **Make your changes** and commit throughout development
2. **Push to repository**: `git push origin your-branch`
3. **Create and push a version tag**:
   ```bash
   git tag v0.7.0
   git push origin v0.7.0
   ```

### Automated Steps

The GitHub Actions workflow will:
- Extract commits since last tag
- Filter and format changelog entries
- Update `Changelog.lua` automatically
- Package and release the addon

## Tag Format

Use semantic versioning with a `v` prefix:
- Major version: `v1.0.0`
- Minor version: `v0.7.0`
- Patch version: `v0.6.1`

The changelog window will trigger for major and minor versions only (not patch versions).

## Commit Message Best Practices

Write clear commit messages that will make sense in a changelog:

### Good Examples ✅
```
Add support for boss encounter phases
Fix countdown timer accuracy issues
Improve notification sound quality
Update UI to match AbstractFramework patterns
```

### Avoid ❌
```
WIP
Update stuff
Fix
Merge branch 'main'
Initial plan
```

### Tips for Good Commit Messages
- Start with a verb (Add, Fix, Improve, Update, Remove)
- Be specific and descriptive
- Keep it concise (under 72 characters if possible)
- Focus on WHAT changed, not HOW

## Changelog Data Structure

The workflow updates this structure in `Changelog.lua`:

```lua
local CHANGELOG_DATA = {
    {
        version = "0.7.0",  -- Extracted from tag
        changes = {
            "Add support for boss encounter phases",  -- From commits
            "Fix countdown timer accuracy issues",
            "Improve notification sound quality",
        }
    },
    {
        version = "0.6.0",
        changes = { ... }
    },
}
```

## Manual Override

If you need to manually edit the changelog:

1. **Before tagging**: Edit `Changelog.lua` directly, then commit and tag
2. **After automation**: The workflow will add a new entry, you can edit it in a follow-up commit

## Workflow Configuration

Location: `.github/workflows/release.yml`

### Key Features
- **Two-job workflow**: First updates changelog, then packages
- **Smart filtering**: Removes non-user-facing commits
- **Automatic commit**: Commits changes with proper git user
- **Tag update**: Moves tag to include changelog commit
- **Summary report**: Shows what was added to changelog

### Environment Variables
The workflow uses these secrets (configured in GitHub):
- `CF_API_KEY` - CurseForge API key
- `WAGO_API_TOKEN` - Wago.io API token
- `GITHUB_TOKEN` - Automatically provided by GitHub

## Troubleshooting

### Workflow Failed
1. Check the Actions tab in GitHub
2. Review the workflow logs
3. Common issues:
   - No commits since last tag (nothing to add)
   - Permission issues (check GITHUB_TOKEN)
   - Syntax errors in generated Lua

### Changelog Not Updated
1. Verify tag format is correct (v0.7.0)
2. Check if commits exist since last tag
3. Review workflow logs in Actions tab

### Manual Rollback
If the automated changelog is incorrect:

```bash
# Edit Changelog.lua manually
git add Changelog.lua
git commit -m "Fix changelog for v0.7.0"
git push

# Update the tag
git tag -f v0.7.0
git push origin v0.7.0 --force
```

## Testing the Workflow

To test without releasing:

1. **Create a test tag** on a feature branch:
   ```bash
   git checkout -b test-release
   git tag v0.7.0-test
   git push origin test-release
   git push origin v0.7.0-test
   ```

2. **Check Actions tab** to see workflow run

3. **Review the result** in Changelog.lua

4. **Clean up** test tag:
   ```bash
   git tag -d v0.7.0-test
   git push origin :refs/tags/v0.7.0-test
   ```

## Comparison to Manual Process

### Before Automation ❌
1. Manually review commits
2. Manually write changelog entries
3. Edit Changelog.lua
4. Commit and push
5. Create tag
6. Push tag
7. Wait for release

### With Automation ✅
1. Write good commit messages
2. Create and push tag
3. Automated workflow handles the rest

## Future Enhancements

Possible improvements:
- Categorize commits (Features, Fixes, Enhancements)
- Support conventional commits format
- Generate markdown changelog file
- Create GitHub release notes automatically
- Notify Discord/Slack channels

## Related Files

- `.github/workflows/release.yml` - Main workflow
- `Changelog.lua` - Changelog data and UI
- `.pkgmeta` - BigWigs packager configuration
- `CHANGELOG_FEATURE.md` - Feature documentation

## Support

If you encounter issues with the automated changelog:
1. Check workflow logs in GitHub Actions
2. Verify commit messages follow best practices
3. Ensure tag format is correct
4. Review this documentation for common solutions
