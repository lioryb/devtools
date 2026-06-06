# Git Configuration Directory

This directory contains modular Git configuration files for Windows and Linux, designed to organize and manage Git settings, aliases, and tooling preferences across different platforms.

## Overview

The git configuration is split into separate files for better organization and maintainability:
- **User information** (credentials, name, email)
- **Tool preferences** (editor, diff/merge tools)
- **Command aliases** (shortcuts for common git commands)

Platform-specific main config files:
- `win_dot_gitconfig` - For Windows
- `lin_dot_gitconfig` - For Linux/macOS

## Setup Instructions

### Step 1: Choose the correct config file for your platform

#### Windows
Copy `win_dot_gitconfig` to your home directory as `.gitconfig`:

```powershell
# Windows PowerShell
Copy-Item -Path "D:\dev\tools\git\win_dot_gitconfig" -Destination "$env:USERPROFILE\.gitconfig" -Force
```

Or manually copy the file and rename it to `.gitconfig` in your home directory (`C:\Users\YourUsername\`).

#### Linux/macOS
Copy `lin_dot_gitconfig` to your home directory as `.gitconfig`:

```bash
# Linux/macOS
cp ~/dev/tools/git/lin_dot_gitconfig ~/.gitconfig
# Or if the repo is in a different location:
cp /path/to/dev/tools/git/lin_dot_gitconfig ~/.gitconfig
```

### Step 2: Verify the configuration
Check that Git can read the configuration:

```bash
git config --list
```

## Configuration Files

### `win_dot_gitconfig`
**Primary configuration file for Windows** - Copy this to `~/.gitconfig` on Windows systems.

Uses absolute Windows paths (e.g., `D:/dev/tools/git/...`) to reference the modular config files below.

### `lin_dot_gitconfig`
**Primary configuration file for Linux/macOS** - Copy this to `~/.gitconfig` on Linux/macOS systems.

Uses home-relative paths (e.g., `~/dev/tools/git/...`) for cross-platform compatibility.

### `user.config`
**User Information**
- Email: lioryb@gmail.com
- Name: Lior Y. Benjamin

Edit this file to update your Git user credentials.

### `tools.config`
**Tool Preferences**

Configures:
- **Editor**: VS Code (`code --wait`)
- **Diff Tool**: Beyond Compare 5
- **Merge Tool**: Beyond Compare 5
- **Line Endings**: Automatic conversion to LF on commit (`autocrlf = input`)

Edit this file if you use different tools or want to change the default editor.

### `aliases.config`
**Git Command Aliases**

Provides convenient shortcuts for common Git operations:

| Alias | Command | Purpose |
|-------|---------|---------|
| `l` | `log` | Show commit log |
| `b` | `branch` | List branches |
| `s` | `status` | Show status |
| `d` | `diff` | Show differences |
| `co` | `checkout` | Switch branches/files |
| `cp` | `cherry-pick` | Apply specific commits |
| `dt` | `difftool` | Open diff tool |
| `rbc` | `rebase --continue` | Continue rebase |
| `pl` | Pretty log with formatting | Formatted commit history |
| `pfl` | Pretty log with full body | Commit history with message bodies |
| `sc` | Status (tracked files only) | Show status excluding untracked files |
| `wip` | Create WIP commit | Quick work-in-progress commit |
| `fixup` | Create fixup commit | Mark a commit as a fixup |

## Usage Examples

After setup, you can use the aliases:

```bash
# Use short aliases
git s                    # git status
git co -b feature/new    # git checkout -b feature/new
git l -10                # git log (last 10 commits)
git d                    # git diff

# Use formatted log
git pl                   # Pretty log with nice formatting
git pfl -5               # Pretty log with full bodies (last 5 commits)

# Work-in-progress shortcuts
git wip "saving progress"  # Commits with [WIP] prefix
git fixup "bug fix"        # Commits with [WIP] fixup prefix
```

## Customization

You can customize these settings:

1. **Change user info**: Edit `user.config`
2. **Change tools**: Edit `tools.config` (update paths to your tools)
3. **Add/modify aliases**: Edit `aliases.config`
4. **Add new config sections**: Create new `.config` files and add include directives to both `win_dot_gitconfig` and `lin_dot_gitconfig`

After making changes to any config file, Git will automatically pick them up (no restart needed).

## Platform Differences

| Aspect | Windows (`win_dot_gitconfig`) | Linux/macOS (`lin_dot_gitconfig`) |
|--------|------|---|
| **Path format** | Absolute Windows paths (e.g., `D:/dev/tools/git/...`) | Home-relative paths (e.g., `~/dev/tools/git/...`) |
| **Tool paths** | Windows tool locations (e.g., `C:\Program Files\...`) | Unix tool paths (e.g., `/usr/bin/...`) |
| **Shared config files** | Uses same `user.config`, `tools.config`, `aliases.config` | Same as Windows |

## Notes

- Line endings are automatically converted to LF on commit (`autocrlf = input`) and set to LF in the repository (`eol = lf`)
- Beyond Compare is configured as the diff and merge tool (may need to adjust path on Linux/macOS)
- VS Code is configured as the default editor for Git operations
- Keep both platform config files in sync when making global changes to shared config files
