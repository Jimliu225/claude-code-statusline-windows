# ~/.claude/statusline.ps1 — Claude Code session status line (Windows edition)
#
# Three-line output:
#   Line 1: ◆ Model │ Gradient progress bar % │ Cost │ Duration │ Rate limits
#   Line 2: ⎇Branch* │ +add/-rm │ Directory
#
# Environment variables:
#   CLAUDE_STATUSLINE_ASCII=1      Fall back to pure ASCII
#   CLAUDE_STATUSLINE_NERDFONT=1   Enable Nerd Font icons
#   CLAUDE_STATUSLINE_POWERLINE=1  Enable Powerline separators (follows NERDFONT)
#
# Requirements:
#   - Windows Terminal (recommended) or any terminal with ANSI support
#   - PowerShell 5.1+ or PowerShell 7+
#   - jq.exe (https://jqlang.org/download/) — place in PATH or C:\Windows\System32\

# ═══════════════════════════════════════════════════════════════
# Windows UTF-8 & ANSI setup
# ═══════════════════════════════════════════════════════════════

# Force UTF-8 output for Unicode symbols
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Enable ANSI escape sequences on Windows 10+
$null = [System.Console]::OutputEncoding
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinConsole {
    [DllImport("kernel32.dll")]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll")]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
}
"@ -ErrorAction SilentlyContinue

try {
    $handle = [WinConsole]::GetStdHandle(-11)  # STD_OUTPUT_HANDLE
    $mode = 0
    [WinConsole]::GetConsoleMode($handle, [ref]$mode) | Out-Null
    [WinConsole]::SetConsoleMode($handle, $mode -bor 4) | Out-Null  # ENABLE_VIRTUAL_TERMINAL_PROCESSING
} catch { }

# ═══════════════════════════════════════════════════════════════
# Environment detection
# ═══════════════════════════════════════════════════════════════

$USE_ASCII    = ($env:CLAUDE_STATUSLINE_ASCII -eq "1")
$USE_NERDFONT = ($env:CLAUDE_STATUSLINE_NERDFONT -eq "1")
$USE_POWERLINE = if ($env:CLAUDE_STATUSLINE_POWERLINE) { $env:CLAUDE_STATUSLINE_POWERLINE -eq "1" } else { $USE_NERDFONT }
$USE_TRUECOLOR = ($env:COLORTERM -eq "truecolor" -or $env:COLORTERM -eq "24bit" -or $env:WT_SESSION -ne $null)

# ═══════════════════════════════════════════════════════════════
# Colors (ANSI escape codes)
# ═══════════════════════════════════════════════════════════════

$ESC  = [char]27
$RST     = "$ESC[0m"
$CYAN    = "$ESC[36m"
$BLUE    = "$ESC[34m"
$GRAY    = "$ESC[90m"
$YELLOW  = "$ESC[33m"
$GREEN   = "$ESC[32m"
$RED     = "$ESC[31m"
$MAGENTA = "$ESC[35m"

# Anthropic brand purple (#7266EA)
if ($USE_TRUECOLOR) {
    $PURPLE = "$ESC[38;2;114;102;234m"
} else {
    $PURPLE = "$ESC[35m"
}

# ═══════════════════════════════════════════════════════════════
# Symbols
# ═══════════════════════════════════════════════════════════════

if ($USE_ASCII) {
    $S_BRAND  = "<>"
    $S_BRANCH = ">"
    $S_WARN   = "!"
    $S_PROMPT = ">"
    $S_TIME   = ""
    $S_COST   = ""
    $SEP      = " | "
} elseif ($USE_NERDFONT) {
    $S_BRAND  = [char]0x25C6      # ◆
    $S_BRANCH = " " + [char]0xE0A0  # Nerd Font branch icon
    $S_WARN   = " " + [char]0xF0026  # Nerd Font warning
    $S_PROMPT = [char]0x276F      # ❯
    $S_TIME   = [char]0xF055F + " " # Nerd Font clock
    $S_COST   = [char]0xF0D6 + " " # Nerd Font money
    $SEP      = if ($USE_POWERLINE) { "  " } else { " | " }
} else {
    $S_BRAND  = [char]0x25C6      # ◆
    $S_BRANCH = [char]0x2387      # ⎇
    $S_WARN   = " " + [char]0x26A0 # ⚠
    $S_PROMPT = [char]0x276F      # ❯
    $S_TIME   = ""
    $S_COST   = ""
    $SEP      = " " + [char]0x2502 + " "  # │
}

# ═══════════════════════════════════════════════════════════════
# Fallback output
# ═══════════════════════════════════════════════════════════════

function Write-Fallback {
    param([string]$msg = [char]0x2500)
    Write-Host -NoNewline "$GRAY$msg$RST"
    exit 0
}

# Check for jq
$jqCmd = Get-Command jq -ErrorAction SilentlyContinue
if (-not $jqCmd) {
    # Try common locations
    $jqPaths = @(
        "C:\Windows\System32\jq.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\jqlang.jq*\jq.exe",
        "$env:ProgramFiles\jq\jq.exe",
        "$env:USERPROFILE\scoop\shims\jq.exe"
    )
    $jqExe = $jqPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($jqExe) {
        $jqCmd = $jqExe
    } else {
        Write-Fallback "─ │ jq not found (install: winget install jqlang.jq)"
    }
}

# ═══════════════════════════════════════════════════════════════
# Read JSON from stdin
# ═══════════════════════════════════════════════════════════════

$input = $null
try {
    if ($null -ne [Console]::In) {
        $input = [Console]::In.ReadToEnd()
    }
} catch { }

if (-not $input) {
    Write-Fallback ([char]0x2500)
}

# ═══════════════════════════════════════════════════════════════
# Parse JSON with jq (single call)
# ═══════════════════════════════════════════════════════════════

$jqFilter = @'
  (.model.display_name // ""),
  (.context_window.used_percentage // 0 | tostring),
  (.cost.total_cost_usd // 0 | tostring),
  (.workspace.current_dir // "." | split("/") | last | split("\\") | last),
  (.worktree.branch // ""),
  (.rate_limits.five_hour.used_percentage // -1 | tostring),
  (.rate_limits.seven_day.used_percentage // -1 | tostring),
  (.agent.name // ""),
  (.workspace.current_dir // "."),
  (.cost.total_lines_added // 0 | tostring),
  (.cost.total_lines_removed // 0 | tostring),
  (.cost.total_duration_ms // 0 | tostring),
  (.context_window.context_window_size // 0 | tostring),
  (.worktree.name // ""),
  "END"
'@

try {
    $parsed = $input | & $jqCmd -r $jqFilter 2>$null
} catch {
    Write-Fallback "─ │ parse error"
}

if (-not $parsed) {
    Write-Fallback "─ │ empty parse"
}

$lines = $parsed -split "`n"
if ($lines.Count -lt 14) {
    Write-Fallback "─ │ incomplete data"
}

$model_name  = $lines[0]
$ctx_pct     = $lines[1]
$cost        = $lines[2]
$dir         = $lines[3]
$branch      = $lines[4]
$rate5h      = $lines[5]
$rate7d      = $lines[6]
$agent_name  = $lines[7]
$cwd_full    = $lines[8]
$lines_add   = $lines[9]
$lines_rm    = $lines[10]
$duration_ms = $lines[11]
$ctx_size    = $lines[12]
$wt_name     = $lines[13]

# ═══════════════════════════════════════════════════════════════
# Model
# ═══════════════════════════════════════════════════════════════

$model = if ($model_name) { $model_name } else { [char]0x2500 }

# ═══════════════════════════════════════════════════════════════
# Context progress bar
# ═══════════════════════════════════════════════════════════════

$pct_int = 0
try { $pct_int = [int][double]$ctx_pct } catch { }
if ($pct_int -lt 0)   { $pct_int = 0 }
if ($pct_int -gt 100) { $pct_int = 100 }

$bar_filled = [Math]::Min([Math]::Floor($pct_int / 10), 10)

# Gradient colors: green → yellow → orange → red
$GRAD_R = @(46, 116, 186, 241, 239, 236, 233, 231, 211, 192)
$GRAD_G = @(204, 195, 186, 196, 161, 126, 101, 76, 66, 57)
$GRAD_B = @(113, 89, 64, 15, 24, 34, 44, 60, 50, 43)

$BLOCK = [char]0x2588  # █
$SHADE = [char]0x2591  # ░

$bar = ""
if ($USE_ASCII) {
    for ($i = 0; $i -lt 10; $i++) {
        $bar += if ($i -lt $bar_filled) { "#" } else { "-" }
    }
} elseif ($USE_TRUECOLOR) {
    for ($i = 0; $i -lt 10; $i++) {
        if ($i -lt $bar_filled) {
            $bar += "$ESC[38;2;$($GRAD_R[$i]);$($GRAD_G[$i]);$($GRAD_B[$i])m$BLOCK"
        } else {
            $bar += "$ESC[38;2;60;60;60m$SHADE"
        }
    }
    $bar += $RST
} else {
    $bar_color = if ($pct_int -ge 90) { $RED } elseif ($pct_int -ge 70) { $YELLOW } else { $GREEN }
    for ($i = 0; $i -lt 10; $i++) {
        $bar += if ($i -lt $bar_filled) { $BLOCK } else { $SHADE }
    }
    $bar = "$bar_color$bar$RST"
}

$pct_color = if ($pct_int -ge 90) { $RED } elseif ($pct_int -ge 70) { $YELLOW } else { $GREEN }

$ctx_warn = ""
if ($pct_int -ge 90) { $ctx_warn = "$RED$S_WARN$RST" }

$ctx_size_int = 0
try { $ctx_size_int = [int]$ctx_size } catch { }
$ctx_label = ""
if ($model -notmatch "context|Context") {
    if ($ctx_size_int -ge 1000000)   { $ctx_label = " $($GRAY)1M$RST" }
    elseif ($ctx_size_int -ge 200000) { $ctx_label = " $($GRAY)200k$RST" }
}

# ═══════════════════════════════════════════════════════════════
# Cost
# ═══════════════════════════════════════════════════════════════

$cost_val = 0.0
try { $cost_val = [double]$cost } catch { }
$cost_fmt = $cost_val.ToString("F2")
$cost_int = [int][Math]::Floor($cost_val)

$cost_color = if ($cost_int -ge 10)        { $RED }
              elseif ($cost_int -ge 5)     { $YELLOW }
              elseif ($cost_fmt -eq "0.00") { $GRAY }
              else                          { $YELLOW }

# ═══════════════════════════════════════════════════════════════
# Duration
# ═══════════════════════════════════════════════════════════════

$dur_ms = 0
try { $dur_ms = [long]$duration_ms } catch { }
$dur_section = ""
if ($dur_ms -gt 0) {
    $dur_sec = [long]($dur_ms / 1000)
    $dur_min = [long]($dur_sec / 60)
    $dur_s   = $dur_sec % 60
    if ($dur_min -gt 0 -or $dur_s -gt 0) {
        $dur_section = "$SEP$($GRAY)$($S_TIME)$($dur_min)m$($dur_s)s$RST"
    }
}

# ═══════════════════════════════════════════════════════════════
# Git branch & dirty flag (with Windows-compatible caching)
# ═══════════════════════════════════════════════════════════════

$GIT_CACHE = "$env:TEMP\claude-statusline-git-cache.txt"
$GIT_CACHE_MAX_AGE = 5  # seconds

$git_branch = $branch
$dirty = ""

function Get-GitCacheAge {
    if (-not (Test-Path $GIT_CACHE)) { return 9999 }
    $lastWrite = (Get-Item $GIT_CACHE).LastWriteTime
    return [int](New-TimeSpan -Start $lastWrite -End (Get-Date)).TotalSeconds
}

if ($cwd_full -and (Test-Path $cwd_full)) {
    if ((Get-GitCacheAge) -gt $GIT_CACHE_MAX_AGE) {
        try {
            $isGit = git -C $cwd_full rev-parse --git-dir 2>$null
            if ($isGit) {
                $cached_branch = $git_branch
                if (-not $cached_branch) {
                    $cached_branch = git -C $cwd_full branch --show-current 2>$null
                    if (-not $cached_branch) {
                        $cached_branch = git -C $cwd_full rev-parse --short HEAD 2>$null
                    }
                }
                $cached_dirty = ""
                $unstaged  = git -C $cwd_full diff --quiet 2>$null; $u = $LASTEXITCODE
                $staged    = git -C $cwd_full diff --cached --quiet 2>$null; $s = $LASTEXITCODE
                if ($u -ne 0 -or $s -ne 0) { $cached_dirty = "*" }
                "$cached_branch|$cached_dirty" | Set-Content $GIT_CACHE -Encoding UTF8
            } else {
                "|" | Set-Content $GIT_CACHE -Encoding UTF8
            }
        } catch {
            "|" | Set-Content $GIT_CACHE -Encoding UTF8
        }
    }

    if (Test-Path $GIT_CACHE) {
        $cacheLine = Get-Content $GIT_CACHE -Raw
        $parts2 = $cacheLine.TrimEnd() -split '\|', 2
        if (-not $git_branch -and $parts2[0]) { $git_branch = $parts2[0] }
        if ($parts2.Count -gt 1) { $dirty = $parts2[1] }
    }
}

# ═══════════════════════════════════════════════════════════════
# Lines added/removed
# ═══════════════════════════════════════════════════════════════

$la = 0; $lr = 0
try { $la = [int]$lines_add } catch { }
try { $lr = [int]$lines_rm } catch { }
$lines_section = ""
if ($la -gt 0 -or $lr -gt 0) {
    $lines_section = "$($GREEN)+$la$RST/$($RED)-$lr$RST"
}

# ═══════════════════════════════════════════════════════════════
# Rate limits
# ═══════════════════════════════════════════════════════════════

$rate5h_int = -1; $rate7d_int = -1
try { $rate5h_int = [int][double]$rate5h } catch { }
try { $rate7d_int = [int][double]$rate7d } catch { }

$rate_parts = ""
if ($rate5h_int -ge 0) {
    $rc = if ($rate5h_int -ge 80) { $RED } else { $GRAY }
    $rate_parts += "$rc`5h:$rate5h_int%$RST"
}
if ($rate7d_int -ge 0) {
    if ($rate_parts) { $rate_parts += " " }
    $rc = if ($rate7d_int -ge 80) { $RED } else { $GRAY }
    $rate_parts += "$rc`7d:$rate7d_int%$RST"
}
$rate_section = if ($rate_parts) { "$SEP$rate_parts" } else { "" }

# ═══════════════════════════════════════════════════════════════
# Prompt color (tied to context usage)
# ═══════════════════════════════════════════════════════════════

$prompt_color = if ($pct_int -ge 90) { $RED } elseif ($pct_int -ge 70) { $YELLOW } else { $GREEN }

# ═══════════════════════════════════════════════════════════════
# Assemble Line 1
# ═══════════════════════════════════════════════════════════════

$line1  = "$PURPLE$S_BRAND$RST $CYAN$model$RST"
$line1 += "$SEP$bar $pct_color$pct_int%$RST$ctx_warn$ctx_label"
$line1 += "$SEP$cost_color$S_COST`$$cost_fmt$RST"
$line1 += $dur_section
$line1 += $rate_section

# ═══════════════════════════════════════════════════════════════
# Assemble Line 2
# ═══════════════════════════════════════════════════════════════

$parts_arr = [System.Collections.Generic.List[string]]::new()

if ($git_branch) {
    $parts_arr.Add("$GRAY$S_BRANCH$git_branch$dirty$RST")
}
if ($lines_section) {
    $parts_arr.Add($lines_section)
}

# Normalize Windows path separators and replace home dir with ~
$display_dir = $dir
if (-not $display_dir -and $cwd_full) {
    $display_dir = Split-Path $cwd_full -Leaf
}
$parts_arr.Add("$BLUE$display_dir$RST")

if ($wt_name) {
    $parts_arr.Add("$YELLOW`⚙ worktree:$wt_name$RST")
} elseif ($agent_name) {
    $parts_arr.Add("$YELLOW`⚙ $agent_name$RST")
}

$line2 = ""
for ($i = 0; $i -lt $parts_arr.Count; $i++) {
    if ($i -gt 0) { $line2 += $SEP }
    $line2 += $parts_arr[$i]
}

# ═══════════════════════════════════════════════════════════════
# Output
# ═══════════════════════════════════════════════════════════════

Write-Host $line1
Write-Host -NoNewline $line2
