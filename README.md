<p align="center">
  <img src="docs/images/cover.jpeg" alt="claude-code-statusline" width="100%">
</p>

# ◆ claude-code-statusline

**English** | [繁體中文](README.zh-TW.md)

A beautiful, information-dense status line for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — the CLI tool by Anthropic. Works on **macOS, Linux, and Windows**.

Turn the blank status bar into a real-time dashboard: model, context usage with gradient progress bar, cost, duration, git branch, rate limits, and more.

## Preview

**Normal** — Context at 42%, everything is fine

![Normal](docs/images/normal.svg)

**Warning** — Context at 75%, pay attention

![Warning](docs/images/warning.svg)

**Danger** — Context at 92%, almost full

![Danger](docs/images/danger.svg)

**Startup** — Clean, no noise

![Startup](docs/images/startup.svg)

## Features

| Feature | Description |
|---------|-------------|
| **Gradient progress bar** | True-color (24-bit) gradient from green → yellow → red. Falls back to ANSI 256 colors or ASCII automatically. |
| **Smart hiding** | Zero values (`+0/-0`, `0m0s`, rate limits) are hidden. `$0.00` stays but dims. |
| **Dynamic cost coloring** | Yellow by default, red when > $10. |
| **Git branch + dirty** | Shows branch name with `*` for uncommitted changes. Cached for 5 seconds to stay fast. |
| **Rate limits** | 5-hour and 7-day usage (Claude Pro/Max only). Red when > 80%. |
| **Agent / Worktree indicator** | `⚙ code-reviewer` or `⚙ worktree:my-feature` — only when active. |
| **Context window size** | Shows `1M` or `200k` only when not already in the model name. |
| **Brand identity** | `◆` diamond in Anthropic purple (#7266EA). |
| **3-tier rendering** | True color → ANSI → ASCII. Works in any terminal. |
| **Nerd Font support** | Optional icons. Set `CLAUDE_STATUSLINE_NERDFONT=1`. |
| **Powerline separators** | Optional arrows. Set `CLAUDE_STATUSLINE_POWERLINE=1`. |
| **< 50ms** | Single `jq` call + cached git. No perceptible lag. |
| **Windows support** | Native PowerShell script (`statusline.ps1`) with full ANSI color support. |

## Installation

### macOS / Linux

#### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- `jq` — install with `brew install jq` (macOS) or `apt install jq` (Linux)

#### Quick install

```bash
git clone https://github.com/kcchien/claude-code-statusline.git
cd claude-code-statusline
./install.sh
```

#### Manual install

```bash
# 1. Copy the script
cp statusline.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Add this to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "timeout": 10
  }
}
```

Restart Claude Code. The status line appears after your first interaction.

---

### Windows

#### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- PowerShell 5.1+ (built-in on Windows 10/11) or [PowerShell 7+](https://github.com/PowerShell/PowerShell/releases)
- [Windows Terminal](https://aka.ms/terminal) (recommended for best color support)
- `jq` — install with one of:
  ```powershell
  winget install jqlang.jq   # Windows Package Manager (recommended)
  scoop install jq           # Scoop
  choco install jq           # Chocolatey
  ```

#### Quick install (PowerShell)

```powershell
git clone https://github.com/kcchien/claude-code-statusline.git
cd claude-code-statusline
.\install.ps1
```

#### One-liner install

```powershell
irm https://raw.githubusercontent.com/kcchien/claude-code-statusline/main/install.ps1 | iex
```

#### Manual install (Windows)

```powershell
# 1. Create the .claude directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude"

# 2. Copy the script
Copy-Item statusline.ps1 "$env:USERPROFILE\.claude\statusline.ps1"

# 3. Allow script execution (run once)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Add this to your `%USERPROFILE%\.claude\settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%USERPROFILE%\\.claude\\statusline.ps1\"",
    "timeout": 10
  }
}
```

Restart Claude Code. The status line appears after your first interaction.

#### Windows Tips

- **Best colors**: Use [Windows Terminal](https://aka.ms/terminal). It supports true-color (24-bit) gradients out of the box.
- **Enable gradient bar**: Set the `COLORTERM` environment variable:
  ```powershell
  [System.Environment]::SetEnvironmentVariable("COLORTERM", "truecolor", "User")
  ```
  Then restart your terminal.
- **Nerd Font icons**: Install a [Nerd Font](https://www.nerdfonts.com/) in Windows Terminal, then:
  ```powershell
  [System.Environment]::SetEnvironmentVariable("CLAUDE_STATUSLINE_NERDFONT", "1", "User")
  ```
- **Execution policy errors**: If you see a "cannot be loaded" error, run:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

---

## Configuration

All configuration is via environment variables.

**macOS/Linux** — add to `~/.zshrc` or `~/.bashrc`:
```bash
export CLAUDE_STATUSLINE_NERDFONT=1
```

**Windows** — set via PowerShell (persists across sessions):
```powershell
[System.Environment]::SetEnvironmentVariable("CLAUDE_STATUSLINE_NERDFONT", "1", "User")
```

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_STATUSLINE_ASCII` | `0` | Set to `1` for pure ASCII mode (no Unicode) |
| `CLAUDE_STATUSLINE_NERDFONT` | `0` | Set to `1` to enable [Nerd Font](https://www.nerdfonts.com/) icons |
| `CLAUDE_STATUSLINE_POWERLINE` | follows NERDFONT | Set to `1` for Powerline arrow separators |
| `COLORTERM` | (system) | `truecolor` or `24bit` enables gradient progress bar |

## How it works

Claude Code's `statusLine` hook sends a JSON payload to your script via stdin after every assistant response. The JSON contains the full session state — model, tokens, cost, git info, rate limits, etc.

This script:

1. **Single `jq` call** (~3ms) — parses all 14 fields at once
2. **Git cache** (~0ms on cache hit, ~40ms on refresh) — dirty check cached for 5 seconds in `/tmp/` (macOS/Linux) or `%TEMP%` (Windows)
3. **Smart assembly** — only non-zero sections are rendered
4. **`printf '%b'` / `Write-Host`** — interprets ANSI escape codes for the final colored output

Total: **< 50ms** end-to-end.

### Available data from Claude Code

The status line receives [these JSON fields](https://code.claude.com/docs/en/statusline#available-data):

- `model.display_name` — current model
- `context_window.used_percentage` — context usage (0-100)
- `cost.total_cost_usd` — session cost
- `cost.total_duration_ms` — elapsed time
- `cost.total_lines_added/removed` — code changes
- `rate_limits.five_hour/seven_day.used_percentage` — rate limits
- `worktree.branch/name` — git worktree info
- `agent.name` — subagent name
- ...and more. See the [official docs](https://code.claude.com/docs/en/statusline).

## Testing

**macOS/Linux:**

```bash
chmod +x examples/test-mock.sh
./examples/test-mock.sh          # All scenarios
./examples/test-mock.sh normal   # Just normal state
./examples/test-mock.sh danger   # Just danger state
./examples/test-mock.sh ascii    # ASCII fallback
```

**Windows — quick test in PowerShell:**

```powershell
'{"model":{"display_name":"Claude Sonnet 4.5"},"context_window":{"used_percentage":42,"context_window_size":200000},"cost":{"total_cost_usd":1.23,"total_duration_ms":125000,"total_lines_added":50,"total_lines_removed":10},"rate_limits":{"five_hour":{"used_percentage":20},"seven_day":{"used_percentage":15}},"workspace":{"current_dir":"C:/Users/you/project"},"worktree":{"branch":"main"}}' | powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\statusline.ps1"
```

## Platform comparison

| Feature | macOS/Linux (`statusline.sh`) | Windows (`statusline.ps1`) |
|---------|-------------------------------|----------------------------|
| Runtime | Bash 3.2+ | PowerShell 5.1+ |
| `jq` required | Yes | Yes |
| True-color gradient | Yes (`COLORTERM=truecolor`) | Yes (Windows Terminal auto-detected) |
| Git dirty check | Yes | Yes |
| Cache location | `/tmp/claude-statusline-git-cache` | `%TEMP%\claude-statusline-git-cache.txt` |
| Nerd Font support | Yes | Yes |
| Powerline support | Yes | Yes |

## Bash 3.2 compatibility (macOS/Linux)

This script is designed for macOS's default bash 3.2. Key design decisions:

- **Lookup table for progress bar** — avoids UTF-8 substring issues across bash versions
- **Line-by-line `read`** — bash 3.2's `IFS` + `read` silently collapses empty delimited fields. Using one `read` per line avoids this.
- **Sentinel value in `jq`** — `$()` strips trailing newlines, which eats the last field if it's empty. A `"END"` sentinel prevents this.

## License

MIT — see [LICENSE](LICENSE).

## Credits

Built with [Claude Code](https://claude.ai/claude-code) (Opus 4.6, 1M context) in a single session. The status line was designed iteratively — from functional prototype to aesthetic dashboard — through collaborative conversation.

Inspired by the [official statusline documentation](https://code.claude.com/docs/en/statusline) and community projects like [ccstatusline](https://github.com/sirmalloc/ccstatusline) and [starship-claude](https://github.com/martinemde/starship-claude).
