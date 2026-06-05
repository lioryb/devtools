<#
 .SYNOPSIS      Automation script to isolate and execute the cloud-init ISO generator.
 .DESCRIPTION   This PowerShell script sets up a localized Python virtual environment
                (.venv), installs required dependencies inside the isolation layer,
                and securely runs the `seed_iso_generator.py` script.

                It dynamically calculates pathing relationships to locate files
                residing in sibling directories under a shared parent folder.

 .NOTES         Author: Lior Y. Benjamin
                Date:   June 2026
                Requires: Python 3.x installed and added to the system Environment PATH.

 .EXAMPLE       .\isoGenExectuer.ps1
                Runs the entire pipeline interactively.
#>

# ==============================================================================
# ADVANCED FUNCTION FEATURE: [CmdletBinding()]
# ==============================================================================
# Explanation: [CmdletBinding()] is an attribute that elevates a standard script
# into an "Advanced Function," making it behave like a native built-in cmdlet.
#
# Core Capabilities unlocked here:
# 1. Strict Parameter Validation: If a user types a wrong parameter name (e.g.,
#    -UserDataa), PowerShell throws a hard error instead of silently passing it.
# 2. Inherited Common Parameters: Automatically provides access to core engines
#    like -Verbose, -Debug, and -ErrorAction without manual programming.
# 3. Pipeline Consistency: Standardizes execution logging, allowing functions like
#    Write-Verbose to safely stream system information to the terminal.
# ==============================================================================
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$UserData,

    [Parameter(Mandatory = $false)]
    [string]$MetaData
)

# ==============================================================================
# STEP 1: DYNAMIC BASE PATH RESOLUTION (GIT ROOT VS. TWO-LEVELS-UP FALLBACK)
# ==============================================================================
# Explanation: This block checks if the code is running inside a Git workspace.
# If it is, it uses 'git rev-parse' to find the true root of the repository.
# If Git isn't installed or the folder isn't versioned, it seamlessly falls back
# to stepping exactly two directory levels up from the script's physical location.
# ==============================================================================

$BASE_ROOT_DIR = $null

# Check if git is available and if this directory is inside a git work tree
if (Get-Command "git" -ErrorAction SilentlyContinue) {
    # Run git command to get the top-level repository path string
    $gitRoot = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($gitRoot)) {
        # Convert forward slashes from Git output to native Windows backslashes
        $BASE_ROOT_DIR = [System.IO.Path]::GetFullPath($gitRoot)
        Write-Verbose "Git repository detected. Root bound to workspace engine base: $BASE_ROOT_DIR"
    }
}

# Fallback mechanism if Git is absent or the script is running standalone outside a repo
if ($null -eq $BASE_ROOT_DIR) {
    $BASE_ROOT_DIR = (Get-Item "$PSScriptRoot\..\..").FullName
    Write-Verbose "Standalone context. Fallback execution path locked to two levels up: $BASE_ROOT_DIR"
}

# Formulate absolute operational path layout targets relative to the discovered base root
$GENERATOR_DIR      = Join-Path $BASE_ROOT_DIR "python\isoGen"
$PY_SCRIPT          = Join-Path $GENERATOR_DIR "isoGen.py"
$VENV_DIR           = Join-Path $GENERATOR_DIR ".venv"
$ACTIVATE           = Join-Path $VENV_DIR "Scripts\Activate.ps1"


Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " Cloud-Init Environment Automation Setup            " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "[+] Target Root Base Context: $BASE_ROOT_DIR" -ForegroundColor Gray

# ==============================================================================
# STEP 2: THE CRITICAL PRE-FLIGHT GUARD
# ==============================================================================
# Explanation: Modifying the host disk by creating a virtual environment is
# wasteful if the underlying task cannot execute. This guard checks for the
# absolute existence of the 'seed_iso_generator.py' script first. If missing,
# it cleanly aborts before making structural alterations to the file system.
# ==============================================================================
Write-Host "[*] Validating target script location..." -ForegroundColor Yellow
if (-not (Test-Path $PY_SCRIPT)) {
    Write-Host ""
    Write-Host "[-] ERROR: Operational engine file not found!" -ForegroundColor Red
    Write-Host "    Expected Path: $PY_SCRIPT" -ForegroundColor DarkYellow
    Write-Host "    Aborting setup process before creating virtual environment structures." -ForegroundColor Red
    Write-Host "====================================================" -ForegroundColor Cyan
    Exit 1
}
Write-Host "[+] Verified target script exists: $PY_SCRIPT" -ForegroundColor Green


# ==============================================================================
# STEP 3: SYSTEM PYTHON VALIDATION
# ==============================================================================
# Explanation: Virtual environments cannot be built out of thin air; they require
# an underlying, system-installed copy of Python to orchestrate the build.
# This block pings the operating system via Get-Command to verify 'python'
# exists on the environment variables PATH.
# ==============================================================================
Write-Host "[*] Checking for system Python installation..." -ForegroundColor Yellow
if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
    Write-Error "Python was not found on your system. Please install Python 3 and add it to your PATH."
    Exit 1
}


# ==============================================================================
# STEP 4: ISOLATED VIRTUAL ENVIRONMENT BOOTSTRAPPING
# ==============================================================================
# Explanation: Modifying global environments can corrupt system tools or break
# separate projects. If a local `.venv` directory does not exist at the calculated
# workspace root, this block invokes Python's standard `venv` engine to create
# an isolated execution boundary.
# ==============================================================================
if (-not (Test-Path $VENV_DIR)) {
    Write-Host "[*] Virtual environment not found. Creating '.venv' at base root..." -ForegroundColor Yellow
    # Spawns Python processing safely without throwing extra pop-up windows
    Start-Process "python" -ArgumentList "-m venv $VENV_DIR" -Wait -NoNewWindow
    if (-not (Test-Path $VENV_DIR)) {
        Write-Error "Failed to generate virtual environment folder structure."
        Exit 1
    }
    Write-Host "[+] Virtual environment successfully built." -ForegroundColor Green
} else {
    Write-Host "[+] Virtual environment '.venv' already exists." -ForegroundColor Green
}


# ==============================================================================
# STEP 5: VIRTUAL ENVIRONMENT ACTIVATION
# ==============================================================================
# Explanation: Simply creating a folder doesn't use it. This section points to
# the native PowerShell activation script inside the virtual environment.
# Executing this script overrides standard environment path pointers for the
# remainder of this shell context, ensuring that typing 'python' or 'pip' targets
# the isolated folder rather than the system defaults.
# ==============================================================================
Write-Host "[*] Activating virtual environment layer..." -ForegroundColor Yellow
if (Test-Path $ACTIVATE) {
    & $ACTIVATE
} else {
    Write-Error "Activation script missing at: $ACTIVATE"
    Exit 1
}


# ==============================================================================
# STEP 6: DEPENDENCY SYNCHRONIZATION
# ==============================================================================
# Explanation: Ensures reproducibility. It executes `pip` within the newly active
# sandbox to silently verify that `pip` itself is up-to-date, and that the
# application's core dependency (`pycdlib`) is completely downloaded and ready.
# ==============================================================================
Write-Host "[*] Synchronizing pip packages..." -ForegroundColor Yellow
python -m pip install --upgrade pip --quiet
python -m pip install pycdlib --quiet
Write-Host "[+] Dependencies verified inside environment." -ForegroundColor Green


# ==============================================================================
# STEP 7: ARGUMENT FORWARDING AND LAUNCH
# ==============================================================================
# Explanation: Converts any high-level options passed into the PowerShell script
# directly into standard command-line flags (`-u`, `-m`) that the Python
# sub-process expects, providing clean interface pass-through execution.
# ==============================================================================
Write-Host "[*] Handing off control to production engine..." -ForegroundColor Yellow
$Arguments = @()

# If custom user-data was supplied to PowerShell, wrap it securely and forward it
if ($UserData) {
    $Arguments += "-u", "`"$UserData`""
}
# If custom meta-data was supplied to PowerShell, wrap it securely and forward it
if ($MetaData) {
    $Arguments += "-m", "`"$MetaData`""
}

# Executes the verified Python application inside the fully locked down environment context
python $PY_SCRIPT $Arguments

# --- TEARDOWN ENGINE LAYER ---
Write-Host "[*] Deactivating isolated environment session scope..." -ForegroundColor Yellow
if (Get-Command "deactivate" -ErrorAction SilentlyContinue) {
    deactivate
    Write-Host "[+] Environment successfully detached. Terminal context restored." -ForegroundColor Green
} else {
    Write-Host "[!] Note: Environment was already terminated or out-of-scope." -ForegroundColor DarkYellow
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host " Task Pipeline Finished Successfully.               " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan