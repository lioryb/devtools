# Git-Aware PowerShell Prompt Setup Guide

## 1. Overview

This guide explains how to install a Git-aware PowerShell prompt script so that it is loaded automatically every time a new PowerShell terminal starts.

The prompt script adds Git repository information directly into the PowerShell prompt, including:

* Current Git branch name.
* Detached HEAD state.
* Ahead / behind status relative to upstream.
* Staged file count.
* Unstaged file count.
* Untracked file count.
* Conflict count.
* Active Git operation state, such as:

  * Rebase
  * Merge
  * Cherry-pick
  * Revert
  * Bisect

After installation, opening a new PowerShell terminal inside a Git repository may show a prompt similar to:

```text
[ main ↑1 ✚2 ≈1 …3] C:\Projects\MyRepo>
```

Outside a Git repository, the prompt remains simple:

```text
C:\Users\YourName>
```

---

## 2. Recommended File Layout

The recommended setup is to keep the Git prompt script in a dedicated folder and load it from your PowerShell profile.

Example layout:

```text
Documents
└── PowerShell
    ├── Microsoft.PowerShell_profile.ps1
    └── Scripts
        └── git_prompt.ps1
```

The exact profile path can differ depending on which PowerShell version you use.

PowerShell has separate profiles for:

* Windows PowerShell 5.1
* PowerShell 7+
* Windows Terminal
* VS Code integrated terminal

The safest way to find the correct profile path is to ask PowerShell directly.

---

## 3. Check Which PowerShell You Are Using

Open PowerShell and run:

```powershell
# 1. Print the current PowerShell version so the user knows which profile is being configured.
$powerShellVersion = $PSVersionTable.PSVersion

# 2. Display the version object in the terminal.
$powerShellVersion
```

Typical results:

```text
Major Minor Patch
----- ----- -----
5     1     ...
```

or:

```text
Major Minor Patch
----- ----- -----
7     4     ...
```

If the major version is `5`, you are using Windows PowerShell.

If the major version is `7`, you are using modern PowerShell.

---

## 4. Find Your PowerShell Profile File

Run this command:

```powershell
# 1. Print the profile file path used by the current PowerShell host.
$PROFILE
```

Example output for PowerShell 7:

```text
C:\Users\YourName\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
```

Example output for Windows PowerShell 5.1:

```text
C:\Users\YourName\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
```

This file is loaded automatically every time a new PowerShell terminal starts.

---

## 5. Create the Profile File If It Does Not Exist

Run the following command:

```powershell
# 1. Extract the parent directory of the current PowerShell profile path.
$profileDirectoryPath = Split-Path -Parent $PROFILE

# 2. Create the profile directory if it does not already exist.
if (-not (Test-Path -LiteralPath $profileDirectoryPath)) {
    New-Item -ItemType Directory -Path $profileDirectoryPath -Force | Out-Null
}

# 3. Create the profile file if it does not already exist.
if (-not (Test-Path -LiteralPath $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}

# 4. Print the final profile path for confirmation.
$PROFILE
```

---

## 6. Create a Folder for the Git Prompt Script

A clean approach is to keep helper scripts in a `Scripts` folder next to the PowerShell profile.

Run:

```powershell
# 1. Extract the parent directory of the current PowerShell profile path.
$profileDirectoryPath = Split-Path -Parent $PROFILE

# 2. Define the helper scripts directory path.
$scriptsDirectoryPath = Join-Path -Path $profileDirectoryPath -ChildPath 'Scripts'

# 3. Create the helper scripts directory if it does not already exist.
if (-not (Test-Path -LiteralPath $scriptsDirectoryPath)) {
    New-Item -ItemType Directory -Path $scriptsDirectoryPath -Force | Out-Null
}

# 4. Print the helper scripts directory path for confirmation.
$scriptsDirectoryPath
```

---

## 7. Save the Git Prompt Script

Save the Git-aware prompt script as:

```text
git_prompt.ps1
```

Inside the `Scripts` folder created above.

The final path should look similar to:

```text
C:\Users\YourName\Documents\PowerShell\Scripts\git_prompt.ps1
```

or, for Windows PowerShell 5.1:

```text
C:\Users\YourName\Documents\WindowsPowerShell\Scripts\git_prompt.ps1
```

---

## 8. Verify the Script File Exists

Run:

```powershell
# 1. Build the expected Git prompt script path.
$gitPromptScriptPath = Join-Path -Path (Split-Path -Parent $PROFILE) -ChildPath 'Scripts\git_prompt.ps1'

# 2. Check whether the script file exists.
$gitPromptScriptExists = Test-Path -LiteralPath $gitPromptScriptPath

# 3. Print the script path and existence result.
[PSCustomObject]@{
    GitPromptScriptPath = $gitPromptScriptPath
    Exists              = $gitPromptScriptExists
}
```

Expected result:

```text
Exists : True
```

If `Exists` is `False`, confirm that the file name and folder location are correct.

---

## 9. Load the Script from Your PowerShell Profile

Open your profile file:

```powershell
# 1. Open the current PowerShell profile in Notepad.
notepad $PROFILE
```

Add the following block to the end of the profile file:

```powershell
# 1. Define the Git prompt script path relative to this profile file.
$gitPromptScriptPath = Join-Path -Path (Split-Path -Parent $PROFILE) -ChildPath 'Scripts\git_prompt.ps1'

# 2. Load the Git prompt script only when the file exists.
if (Test-Path -LiteralPath $gitPromptScriptPath) {
    . $gitPromptScriptPath
}

# 3. Print a warning only when the expected script file is missing.
else {
    Write-Warning "Git prompt script was not found: $gitPromptScriptPath"
}
```

Important:

The dot before `$gitPromptScriptPath` is required:

```powershell
. $gitPromptScriptPath
```

This is called **dot-sourcing**.

Dot-sourcing means the functions inside `git_prompt.ps1` are loaded into the current PowerShell session.

Without dot-sourcing, the custom `prompt` function may not remain active after the script finishes.

---

## 10. Restart PowerShell

Close the current PowerShell terminal.

Open a new PowerShell terminal.

The profile should now load automatically.

To verify that the prompt function exists, run:

```powershell
# 1. Search for the active prompt function.
$promptCommand = Get-Command prompt -ErrorAction SilentlyContinue

# 2. Display the command metadata.
$promptCommand
```

Expected result:

```text
CommandType Name   Version Source
----------- ----   ------- ------
Function    prompt
```

---

## 11. Test Inside a Git Repository

Move into any Git repository:

```powershell
# 1. Change to a known Git repository directory.
Set-Location -LiteralPath 'C:\Path\To\Your\Repository'

# 2. Ask Git to confirm the current repository branch.
git branch --show-current
```

Then press `Enter` once.

The prompt should now include Git information.

Example:

```text
[ main ✔] C:\Path\To\Your\Repository>
```

If the repository has changes, you may see something like:

```text
[ main ✚1 ≈2 …3] C:\Path\To\Your\Repository>
```

---

## 12. Configure Optional Prompt Settings

The Git prompt script supports global configuration variables.

These can be set before loading the script in your PowerShell profile.

### 12.1 Use ASCII Symbols Only

Use this when your terminal does not display Unicode or Nerd Font symbols correctly.

Add this before dot-sourcing the script:

```powershell
# 1. Force the Git prompt to use ASCII-safe symbols.
$Global:GitPromptUseAscii = $true
```

Example output:

```text
[git main OK] C:\Projects\MyRepo>
```

Instead of:

```text
[ main ✔] C:\Projects\MyRepo>
```

---

### 12.2 Disable ANSI Colors

Use this when colors look broken or unreadable.

```powershell
# 1. Disable ANSI color rendering in the Git prompt.
$Global:GitPromptEnableColor = $false
```

---

### 12.3 Disable Untracked File Scanning

Use this for very large repositories where the prompt feels slow.

```powershell
# 1. Disable untracked-file scanning to reduce Git status latency.
$Global:GitPromptShowUntracked = $false
```

When disabled, the prompt will not show the untracked file count.

This can improve performance in repositories with many generated files, build folders, dependency folders, or large untracked trees.

---

## 13. Recommended Profile Example

A complete profile setup may look like this:

```powershell
# 1. Configure the Git prompt to use Unicode symbols when the terminal supports them.
$Global:GitPromptUseAscii = $false

# 2. Enable ANSI colors when the current PowerShell host supports them.
$Global:GitPromptEnableColor = $true

# 3. Enable untracked-file scanning for full repository visibility.
$Global:GitPromptShowUntracked = $true

# 4. Define the Git prompt script path relative to the current profile file.
$gitPromptScriptPath = Join-Path -Path (Split-Path -Parent $PROFILE) -ChildPath 'Scripts\git_prompt.ps1'

# 5. Dot-source the Git prompt script when it exists.
if (Test-Path -LiteralPath $gitPromptScriptPath) {
    . $gitPromptScriptPath
}

# 6. Warn the user if the script file is missing.
else {
    Write-Warning "Git prompt script was not found: $gitPromptScriptPath"
}
```

---

## 14. Execution Policy Issues

If PowerShell blocks the script, you may see an error similar to:

```text
running scripts is disabled on this system
```

Check the current execution policy:

```powershell
# 1. Display execution policies for all scopes.
Get-ExecutionPolicy -List
```

For most personal developer machines, this is usually enough:

```powershell
# 1. Allow locally created scripts to run for the current Windows user only.
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

This changes the policy only for the current user.

It does not require changing the policy for the entire machine.

If your computer is managed by an organization, the policy may be controlled by IT.

---

## 15. VS Code Integrated Terminal

VS Code usually loads the same PowerShell profile as the selected PowerShell version.

To verify the active profile inside VS Code:

```powershell
# 1. Print the PowerShell profile path used by the VS Code integrated terminal.
$PROFILE
```

If VS Code uses a different PowerShell version than your normal terminal, it may use a different profile path.

Repeat the setup for the profile path shown inside VS Code.

---

## 16. Windows Terminal

Windows Terminal does not normally require a separate setup.

It launches PowerShell, and PowerShell loads its own profile.

To verify the active profile inside Windows Terminal:

```powershell
# 1. Print the PowerShell profile path used by the current Windows Terminal tab.
$PROFILE
```

If the path is different from the one you configured earlier, install the profile snippet into this profile as well.

---

## 17. Troubleshooting

### 17.1 The Prompt Did Not Change

Check whether the profile is loading:

```powershell
# 1. Add this temporary line to the profile file.
Write-Host 'PowerShell profile loaded'
```

Restart PowerShell.

If the message does not appear, PowerShell is not loading the profile you edited.

Run:

```powershell
# 1. Print the active profile path.
$PROFILE
```

Then edit that exact file.

---

### 17.2 The Script Path Is Wrong

Run:

```powershell
# 1. Rebuild the expected Git prompt script path.
$gitPromptScriptPath = Join-Path -Path (Split-Path -Parent $PROFILE) -ChildPath 'Scripts\git_prompt.ps1'

# 2. Print whether the file exists.
Test-Path -LiteralPath $gitPromptScriptPath

# 3. Print the expected file path.
$gitPromptScriptPath
```

If the result is `False`, move `git_prompt.ps1` to the printed path or update the profile path.

---

### 17.3 Symbols Look Broken

If the prompt shows boxes, question marks, or strange characters, enable ASCII mode:

```powershell
# 1. Force ASCII-safe prompt symbols.
$Global:GitPromptUseAscii = $true
```

Place this before the line that dot-sources `git_prompt.ps1`.

---

### 17.4 Colors Look Broken

Disable colors:

```powershell
# 1. Disable prompt colors.
$Global:GitPromptEnableColor = $false
```

Place this before the line that dot-sources `git_prompt.ps1`.

---

### 17.5 Prompt Is Slow in Large Repositories

Disable untracked-file scanning:

```powershell
# 1. Disable untracked-file scanning for better prompt performance.
$Global:GitPromptShowUntracked = $false
```

Place this before the line that dot-sources `git_prompt.ps1`.

---

### 17.6 Git Is Not Found

Check whether Git is available:

```powershell
# 1. Search for the Git executable in the current PATH.
$gitCommand = Get-Command git -ErrorAction SilentlyContinue

# 2. Display the result.
$gitCommand
```

If no result appears, install Git for Windows and make sure Git is available in `PATH`.

After installing Git, restart PowerShell.

---

## 18. Updating the Git Prompt Script

To update the prompt logic later:

1. Open the `git_prompt.ps1` file.
2. Replace its contents with the new version.
3. Save the file.
4. Restart PowerShell.

Alternatively, reload the current PowerShell session manually:

```powershell
# 1. Reload the current PowerShell profile without restarting the terminal.
. $PROFILE
```

---

## 19. Temporarily Disable the Git Prompt

To disable the prompt temporarily, comment out the dot-source line in your profile.

Change this:

```powershell
# 1. Load the Git prompt script.
. $gitPromptScriptPath
```

To this:

```powershell
# 1. Temporarily disable the Git prompt script.
# . $gitPromptScriptPath
```

Then restart PowerShell.

---

## 20. Uninstall the Git Prompt

To completely remove the Git prompt:

1. Open your PowerShell profile:

```powershell
# 1. Open the current PowerShell profile in Notepad.
notepad $PROFILE
```

2. Remove the block that loads `git_prompt.ps1`.

3. Optionally delete the script file:

```powershell
# 1. Build the Git prompt script path.
$gitPromptScriptPath = Join-Path -Path (Split-Path -Parent $PROFILE) -ChildPath 'Scripts\git_prompt.ps1'

# 2. Delete the script file if it exists.
if (Test-Path -LiteralPath $gitPromptScriptPath) {
    Remove-Item -LiteralPath $gitPromptScriptPath -Force
}
```

4. Restart PowerShell.

The prompt will return to the default PowerShell behavior.

---

## 21. Quick Installation Summary

For a fast setup, use this checklist:

1. Run PowerShell.
2. Run:

```powershell
# 1. Print the active profile path.
$PROFILE
```

3. Create the profile if needed.
4. Create a `Scripts` folder next to the profile.
5. Save the Git prompt script as:

```text
Scripts\git_prompt.ps1
```

6. Add this to the profile:

```powershell
# 1. Configure prompt behavior.
$Global:GitPromptUseAscii = $false
$Global:GitPromptEnableColor = $true
$Global:GitPromptShowUntracked = $true

# 2. Define the Git prompt script path.
$gitPromptScriptPath = Join-Path -Path (Split-Path -Parent $PROFILE) -ChildPath 'Scripts\git_prompt.ps1'

# 3. Load the Git prompt script.
if (Test-Path -LiteralPath $gitPromptScriptPath) {
    . $gitPromptScriptPath
}

# 4. Warn when the script is missing.
else {
    Write-Warning "Git prompt script was not found: $gitPromptScriptPath"
}
```

7. Restart PowerShell.
8. Open a Git repository.
9. Confirm the prompt shows Git status information.

---

## 22. Final Notes

The prompt script is read-only from Git’s perspective.

It does not modify:

* Git branches.
* Git commits.
* Git staging area.
* Git configuration.
* Working tree files.
* Remote repositories.

It only runs Git inspection commands and renders their result in the PowerShell prompt.
