# install.ps1 — Windows installer for claude-code-statusline
#
# Usage (run in PowerShell as normal user):
#   .\install.ps1
#
# Or one-liner (from PowerShell):
#   irm https://raw.githubusercontent.com/kcchien/claude-code-statusline/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$TARGET_DIR  = "$env:USERPROFILE\.claude"
$TARGET_FILE = "$TARGET_DIR\statusline.ps1"
$SETTINGS    = "$TARGET_DIR\settings.json"
$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host ""
Write-Host "[+] claude-code-statusline Windows installer" -ForegroundColor Cyan
Write-Host ""

# ─── Check PowerShell version ────────────────────────────────────────
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "[!] PowerShell 5.1 or higher is required." -ForegroundColor Red
    Write-Host "    Download: https://github.com/PowerShell/PowerShell/releases"
    exit 1
}

# ─── Check for jq ────────────────────────────────────────────────────
$jqFound = $false

$jqCmd = Get-Command jq -ErrorAction SilentlyContinue
if ($jqCmd) {
    $jqFound = $true
    Write-Host "[OK] jq found: $($jqCmd.Source)" -ForegroundColor Green
} else {
    # Try winget
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Host "[i] jq not found. Installing via winget..." -ForegroundColor Yellow
        try {
            winget install --id jqlang.jq -e --accept-package-agreements --accept-source-agreements
            $jqFound = $true
            Write-Host "[OK] jq installed successfully." -ForegroundColor Green
        } catch {
            Write-Host "[!] winget install failed. Please install jq manually:" -ForegroundColor Red
        }
    }

    if (-not $jqFound) {
        Write-Host ""
        Write-Host "[!] jq is required but not installed." -ForegroundColor Red
        Write-Host "    Install options:"
        Write-Host "      winget install jqlang.jq"
        Write-Host "      scoop install jq"
        Write-Host "      choco install jq"
        Write-Host "    Or download from: https://jqlang.org/download/"
        Write-Host ""
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne "y" -and $continue -ne "Y") { exit 1 }
    }
}

# ─── Create .claude directory ─────────────────────────────────────────
if (-not (Test-Path $TARGET_DIR)) {
    New-Item -ItemType Directory -Path $TARGET_DIR | Out-Null
    Write-Host "[OK] Created $TARGET_DIR" -ForegroundColor Green
}

# ─── Copy / download statusline.ps1 ───────────────────────────────────
$localScript = Join-Path $SCRIPT_DIR "statusline.ps1"
if (Test-Path $localScript) {
    Copy-Item $localScript $TARGET_FILE -Force
    Write-Host "[OK] Installed statusline.ps1 to $TARGET_FILE" -ForegroundColor Green
} else {
    Write-Host "[i] Downloading statusline.ps1 ..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest `
            -Uri "https://raw.githubusercontent.com/kcchien/claude-code-statusline/main/statusline.ps1" `
            -OutFile $TARGET_FILE `
            -UseBasicParsing
        Write-Host "[OK] Downloaded to $TARGET_FILE" -ForegroundColor Green
    } catch {
        Write-Host "[!] Download failed: $_" -ForegroundColor Red
        exit 1
    }
}

# ─── Check execution policy ───────────────────────────────────────────
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq "Restricted" -or $policy -eq "AllSigned") {
    Write-Host ""
    Write-Host "[i] Setting PowerShell execution policy to RemoteSigned for CurrentUser..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Host "[OK] Execution policy set to RemoteSigned." -ForegroundColor Green
    } catch {
        Write-Host "[!] Could not set execution policy automatically. Run this manually:" -ForegroundColor Red
        Write-Host "    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    }
}

# ─── Update settings.json ─────────────────────────────────────────────
$settingsCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$TARGET_FILE`""

Write-Host ""
if (Test-Path $SETTINGS) {
    $settingsContent = Get-Content $SETTINGS -Raw -ErrorAction SilentlyContinue
    if ($settingsContent -match '"statusLine"') {
        Write-Host "[!] Your settings.json already has a statusLine config." -ForegroundColor Yellow
        Write-Host "    To use this script, update it to:"
        Write-Host ""
        Write-Host '  "statusLine": {'
        Write-Host '    "type": "command",'
        Write-Host "    `"command`": `"$settingsCmd`","
        Write-Host '    "timeout": 10'
        Write-Host '  }'
        Write-Host ""
    } else {
        Write-Host "    Add this to your $SETTINGS :"
        Write-Host ""
        Write-Host '  "statusLine": {'
        Write-Host '    "type": "command",'
        Write-Host "    `"command`": `"$settingsCmd`","
        Write-Host '    "timeout": 10'
        Write-Host '  }'
        Write-Host ""
    }
} else {
    Write-Host "    No settings.json found. Create $SETTINGS with:"
    Write-Host ""
    Write-Host '{'
    Write-Host '  "statusLine": {'
    Write-Host '    "type": "command",'
    Write-Host "    `"command`": `"$settingsCmd`","
    Write-Host '    "timeout": 10'
    Write-Host '  }'
    Write-Host '}'
    Write-Host ""
}

Write-Host "[OK] Done! Restart Claude Code to see the status line." -ForegroundColor Green
Write-Host ""
Write-Host "Tips:"
Write-Host "  - Use Windows Terminal for best color support"
Write-Host "  - Set COLORTERM=truecolor for gradient progress bar:"
Write-Host '    [System.Environment]::SetEnvironmentVariable("COLORTERM","truecolor","User")'
Write-Host "  - Enable Nerd Fonts: set CLAUDE_STATUSLINE_NERDFONT=1"
Write-Host ""
