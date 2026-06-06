# Git-aware PowerShell prompt for interactive use.
# Add this file to your PowerShell profile or dot-source it from $PROFILE.
#
# Operational goals:
# - Safe read-only inspection of Git repository state.
# - Clear, deterministic prompt rendering.
# - Compatibility with Windows PowerShell 5.1 and PowerShell 7+.
# - Minimal surprises outside Git repositories.
# - Robust handling of branch names, worktrees, submodules, and transient Git operations.

# 1. Initialize global configuration variables only when the caller has not already configured them.
#    This preserves user preferences across reloads and avoids clobbering profile-level customization.
if (-not (Get-Variable -Name GitPromptUseAscii -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:GitPromptUseAscii = $false
}

# 2. GitPromptEnableColor controls ANSI color rendering.
#    The runtime capability check later still disables color automatically on unsupported shells.
if (-not (Get-Variable -Name GitPromptEnableColor -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:GitPromptEnableColor = $true
}

# 3. GitPromptShowUntracked controls whether Git scans for untracked files.
#    Disabling this can significantly improve prompt latency in very large repositories.
if (-not (Get-Variable -Name GitPromptShowUntracked -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:GitPromptShowUntracked = $true
}

function Get-GitPromptGitPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativeGitPath
    )

    # 1. Ask Git to resolve its own internal metadata path instead of manually joining against .git.
    #    This is safer for worktrees, submodules, linked worktrees, and non-standard repository layouts.
    $resolvedGitPath = git rev-parse --git-path $RelativeGitPath 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $resolvedGitPath) {
        return $null
    }

    # 2. Trim native-command output defensively because PowerShell may preserve line endings.
    #    Boundary condition: if Git returns multiple lines unexpectedly, the first line is the only valid path.
    $resolvedGitPath = @($resolvedGitPath)[0].Trim()
    if (-not $resolvedGitPath) {
        return $null
    }

    # 3. Convert existing paths to provider-qualified paths when possible.
    #    Safety boundary: do not require the path to exist, because some sentinel files are absent by design.
    $resolvedProviderPath = Resolve-Path -LiteralPath $resolvedGitPath -ErrorAction SilentlyContinue
    if ($resolvedProviderPath) {
        return $resolvedProviderPath.Path
    }

    # 4. Return the Git-computed path even when absent, so callers can test it with Test-Path.
    #    This avoids false negatives for operation markers that may appear later in the same repository.
    return $resolvedGitPath
}

function Get-GitOperationState {
    [CmdletBinding()]
    param()

    # 1. Query Git for the active metadata storage directory.
    #    Safety boundary: stderr is suppressed to avoid noisy prompts outside repositories.
    $gitDirectoryRaw = git rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $gitDirectoryRaw) {
        return $null
    }

    # 2. Resolve Git operation paths through Git itself.
    #    This avoids incorrect manual path composition in linked worktrees and submodules.
    $rebaseApplyDirectory = Get-GitPromptGitPath -RelativeGitPath 'rebase-apply'
    $rebaseMergeDirectory = Get-GitPromptGitPath -RelativeGitPath 'rebase-merge'
    $mergeHeadFile        = Get-GitPromptGitPath -RelativeGitPath 'MERGE_HEAD'
    $cherryPickHeadFile   = Get-GitPromptGitPath -RelativeGitPath 'CHERRY_PICK_HEAD'
    $revertHeadFile       = Get-GitPromptGitPath -RelativeGitPath 'REVERT_HEAD'
    $bisectLogFile        = Get-GitPromptGitPath -RelativeGitPath 'BISECT_LOG'
    $bisectStartFile      = Get-GitPromptGitPath -RelativeGitPath 'BISECT_START'

    # 3. Check for mailbox/apply-based rebases.
    #    Boundary condition: this also covers git-am style workflows and older rebase backends.
    if ($rebaseApplyDirectory -and (Test-Path -LiteralPath $rebaseApplyDirectory)) {
        return 'REBASE'
    }

    # 4. Check for interactive or merge-based rebases.
    #    If possible, expose progress as current-step/total-step.
    if ($rebaseMergeDirectory -and (Test-Path -LiteralPath $rebaseMergeDirectory)) {
        $rebaseMessageNumberFile = Join-Path $rebaseMergeDirectory 'msgnum'
        $rebaseEndFile           = Join-Path $rebaseMergeDirectory 'end'

        # 5. Safely read rebase progress without converting read errors into prompt failures.
        #    Safety boundary: missing files fall back to a generic REBASE state.
        $rebaseMessageNumber = Get-Content -LiteralPath $rebaseMessageNumberFile -ErrorAction SilentlyContinue | Select-Object -First 1
        $rebaseEnd           = Get-Content -LiteralPath $rebaseEndFile           -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($rebaseMessageNumber -and $rebaseEnd) {
            return "REBASE $rebaseMessageNumber/$rebaseEnd"
        }

        return 'REBASE'
    }

    # 6. Evaluate high-signal file markers to identify active transient repository states.
    #    Ordering is intentional: rebase is checked first because it may coexist with other metadata.
    if ($mergeHeadFile -and (Test-Path -LiteralPath $mergeHeadFile)) {
        return 'MERGING'
    }

    if ($cherryPickHeadFile -and (Test-Path -LiteralPath $cherryPickHeadFile)) {
        return 'CHERRY-PICKING'
    }

    if ($revertHeadFile -and (Test-Path -LiteralPath $revertHeadFile)) {
        return 'REVERTING'
    }

    # 7. BISECT_START is the stronger active-state marker; BISECT_LOG is retained as a fallback.
    #    Boundary condition: checking both handles Git versions and partial bisect states more robustly.
    if (($bisectStartFile -and (Test-Path -LiteralPath $bisectStartFile)) -or
        ($bisectLogFile   -and (Test-Path -LiteralPath $bisectLogFile))) {
        return 'BISECTING'
    }

    return $null
}

function Get-GitPromptInfo {
    [CmdletBinding()]
    param()

    # 1. Pre-flight check: prevent shell execution stalls and command-not-found noise.
    #    Safety boundary: if Git is unavailable, the prompt silently falls back to a normal path prompt.
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCommand) {
        return $null
    }

    # 2. Select untracked-file scan behavior.
    #    Performance consideration: untracked scanning may be expensive in large repositories.
    if ($Global:GitPromptShowUntracked) {
        $untrackedStatusArgument = '--untracked-files=all'
    }
    else {
        $untrackedStatusArgument = '--untracked-files=no'
    }

    # 3. Execute a single status call to fetch branch tracking and working-tree state together.
    #    The porcelain format is stable for scripts, while color is disabled for deterministic parsing.
    $gitStatusOutput = git -c color.status=false status --porcelain=v1 -b $untrackedStatusArgument 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $gitStatusOutput) {
        return $null
    }

    # 4. Normalize native command output into individual lines.
    #    Boundary condition: PowerShell may return either one multiline string or an array of strings.
    $gitStatusLines = @($gitStatusOutput -split "`r?`n")
    if ($gitStatusLines.Count -eq 0) {
        return $null
    }

    # 5. Extract and validate the mandatory porcelain branch/tracking header.
    $branchMetadataLine = $gitStatusLines[0].Trim()
    if (-not $branchMetadataLine.StartsWith('## ')) {
        return $null
    }

    $branchDisplayName = $null

    # 6. Parse the branch metadata payload.
    #    Safety boundary: if parsing fails, the final fallback below emits "unknown".
    if ($branchMetadataLine -match '^##\s+(.+)$') {
        $branchMetadata = $Matches[1].Trim()

        # 7. Explicitly handle detached HEAD scenarios.
        #    Boundary condition: if the short hash cannot be read, emit a deterministic fallback label.
        if ($branchMetadata -like 'HEAD*') {
            $shortCommitId = git rev-parse --short HEAD 2>$null

            if ($LASTEXITCODE -ne 0 -or -not $shortCommitId) {
                $shortCommitId = 'DETACHED'
            }
            else {
                $shortCommitId = @($shortCommitId)[0].Trim()
            }

            $branchDisplayName = "detached@$shortCommitId"
        }
        else {
            # 8. Strip only the upstream separator, not ordinary dots in branch names.
            #    Correct examples:
            #    - feature/login.v2...origin/feature/login.v2 => feature/login.v2
            #    - release/1.2.3...origin/release/1.2.3   => release/1.2.3
            #    - main                                    => main
            if ($branchMetadata -match '^(.+?)(?:\.\.\.|$)') {
                $branchDisplayName = $Matches[1].Trim()
            }
            else {
                $branchDisplayName = $branchMetadata.Trim()
            }
        }
    }

    # 9. Apply a stable fallback when the branch header has an unexpected shape.
    if (-not $branchDisplayName) {
        $branchDisplayName = 'unknown'
    }

    # 10. Extract upstream synchronization statistics.
    #     Boundary condition: absent counters remain zero for untracked/no-upstream branches.
    $aheadCount = 0
    $behindCount = 0

    if ($branchMetadataLine -match 'ahead\s+(\d+)') {
        $aheadCount = [int]$Matches[1]
    }

    if ($branchMetadataLine -match 'behind\s+(\d+)') {
        $behindCount = [int]$Matches[1]
    }

    # 11. Initialize working-tree state counters.
    $stagedCount    = 0
    $unstagedCount  = 0
    $untrackedCount = 0
    $conflictCount  = 0

    # 12. Iterate over all status entries after the branch header.
    #     Performance consideration: parsing the existing status output avoids additional Git calls.
    foreach ($statusLine in ($gitStatusLines | Select-Object -Skip 1)) {
        if (-not $statusLine -or $statusLine.Length -lt 2) {
            continue
        }

        # 13. Untracked files are strictly marked by "??" in porcelain v1.
        #     Boundary condition: this block is normally unreachable when untracked scanning is disabled.
        if ($statusLine.StartsWith('??')) {
            $untrackedCount++
            continue
        }

        # 14. Split the two-column porcelain status code.
        #     Index 0: staging/index state.
        #     Index 1: working-tree state.
        $indexStatusCode   = $statusLine.Substring(0, 1)
        $workTreeStatusCode = $statusLine.Substring(1, 1)
        $combinedStatusCode = $indexStatusCode + $workTreeStatusCode

        # 15. Detect merge-conflict signatures before normal staged/unstaged counting.
        #     Design choice: conflicted files are counted as conflicts only, avoiding double-counting.
        if ('DD', 'AA', 'UU', 'AU', 'UA', 'DU', 'UD' -contains $combinedStatusCode) {
            $conflictCount++
            continue
        }

        # 16. Count staged tracked mutations.
        if ($indexStatusCode -ne ' ') {
            $stagedCount++
        }

        # 17. Count unstaged tracked mutations.
        if ($workTreeStatusCode -ne ' ') {
            $unstagedCount++
        }
    }

    # 18. Map output glyphs based on terminal typography preference.
    #     Safety boundary: ASCII mode avoids Nerd Font / Unicode rendering assumptions.
    if ($Global:GitPromptUseAscii) {
        $branchSymbol    = 'git'
        $cleanSymbol     = 'OK'
        $stagedSymbol    = '+'
        $unstagedSymbol  = '~'
        $untrackedSymbol = '?'
        $conflictSymbol  = '!'
        $aheadSymbol     = '^'
        $behindSymbol    = 'v'
    }
    else {
        $branchSymbol    = ''
        $cleanSymbol     = '✔'
        $stagedSymbol    = '✚'
        $unstagedSymbol  = '≈'
        $untrackedSymbol = '…'
        $conflictSymbol  = '⚡'
        $aheadSymbol     = '↑'
        $behindSymbol    = '↓'
    }

    # 19. Verify ANSI rendering support without assuming $PSStyle exists.
    #     Compatibility boundary: Windows PowerShell 5.1 does not expose $PSStyle.
    $powerShellStyleVariable = Get-Variable -Name PSStyle -ErrorAction SilentlyContinue
    $powerShellStyleObject   = if ($powerShellStyleVariable) { $powerShellStyleVariable.Value } else { $null }

    $isAnsiColorAvailable =
        $Global:GitPromptEnableColor -and
        ($null -ne $powerShellStyleObject)

    # 20. Build the color map while keeping every color optional.
    #     Safety boundary: unsupported terminals receive plain text without escape sequences.
    $promptColors = @{
        Reset   = if ($isAnsiColorAvailable) { $powerShellStyleObject.Reset                  } else { '' }
        Dim     = if ($isAnsiColorAvailable) { $powerShellStyleObject.Foreground.BrightBlack } else { '' }
        Cyan    = if ($isAnsiColorAvailable) { $powerShellStyleObject.Foreground.Cyan        } else { '' }
        Green   = if ($isAnsiColorAvailable) { $powerShellStyleObject.Foreground.Green       } else { '' }
        Yellow  = if ($isAnsiColorAvailable) { $powerShellStyleObject.Foreground.Yellow      } else { '' }
        Red     = if ($isAnsiColorAvailable) { $powerShellStyleObject.Foreground.Red         } else { '' }
        Blue    = if ($isAnsiColorAvailable) { $powerShellStyleObject.Foreground.Blue        } else { '' }
        Magenta = if ($isAnsiColorAvailable) { $powerShellStyleObject.Foreground.Magenta     } else { '' }
    }

    # 21. Synthesize individual prompt segments into an ordered collection.
    #     Performance consideration: a typed list avoids repeated string concatenation churn.
    $promptSegmentParts = New-Object System.Collections.Generic.List[string]
    $promptSegmentParts.Add("$($promptColors.Cyan)$branchSymbol $branchDisplayName$($promptColors.Reset)")

    # 22. Emit upstream divergence counters only when non-zero.
    if ($aheadCount -gt 0) {
        $promptSegmentParts.Add("$($promptColors.Blue)$aheadSymbol$aheadCount$($promptColors.Reset)")
    }

    if ($behindCount -gt 0) {
        $promptSegmentParts.Add("$($promptColors.Blue)$behindSymbol$behindCount$($promptColors.Reset)")
    }

    # 23. Emit either a clean marker or the non-zero dirty-state counters.
    if ($stagedCount -eq 0 -and
        $unstagedCount -eq 0 -and
        $untrackedCount -eq 0 -and
        $conflictCount -eq 0) {
        $promptSegmentParts.Add("$($promptColors.Green)$cleanSymbol$($promptColors.Reset)")
    }
    else {
        if ($stagedCount -gt 0) {
            $promptSegmentParts.Add("$($promptColors.Green)$stagedSymbol$stagedCount$($promptColors.Reset)")
        }

        if ($unstagedCount -gt 0) {
            $promptSegmentParts.Add("$($promptColors.Yellow)$unstagedSymbol$unstagedCount$($promptColors.Reset)")
        }

        if ($untrackedCount -gt 0) {
            $promptSegmentParts.Add("$($promptColors.Dim)$untrackedSymbol$untrackedCount$($promptColors.Reset)")
        }

        if ($conflictCount -gt 0) {
            $promptSegmentParts.Add("$($promptColors.Red)$conflictSymbol$conflictCount$($promptColors.Reset)")
        }
    }

    # 24. Append active Git operation state, such as rebase, merge, cherry-pick, revert, or bisect.
    $operationState = Get-GitOperationState
    if ($operationState) {
        $promptSegmentParts.Add("$($promptColors.Magenta)| $operationState$($promptColors.Reset)")
    }

    # 25. Join the final Git segment.
    $gitPromptSegment = '[' + ($promptSegmentParts -join ' ') + ']'

    # 26. Return structured metadata for testability and modular integration.
    return @{
        Segment        = $gitPromptSegment
        IsRepo         = $true
        Branch         = $branchDisplayName
        Ahead          = $aheadCount
        Behind         = $behindCount
        Staged         = $stagedCount
        Unstaged       = $unstagedCount
        Untracked      = $untrackedCount
        Conflicts      = $conflictCount
        OperationState = $operationState
    }
}

function prompt {
    [CmdletBinding()]
    param()

    # 1. Capture the active workspace path from the current PowerShell location.
    #    Boundary condition: this intentionally mirrors PowerShell's provider path behavior.
    $currentPath = (Get-Location).Path

    # 2. Query Git prompt metadata.
    #    Safety boundary: all Git failures return null and fall back to a normal prompt.
    $gitPromptInfo = Get-GitPromptInfo

    # 3. Render a Git-aware prompt only inside a valid repository.
    if ($gitPromptInfo -and $gitPromptInfo.IsRepo) {
        return "$($gitPromptInfo.Segment) $currentPath> "
    }

    # 4. Render the standard fallback prompt outside Git repositories.
    return "$currentPath> "
}
