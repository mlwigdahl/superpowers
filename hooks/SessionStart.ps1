# SessionStart hook for superpowers plugin (PowerShell)
# Save as: SessionStart.ps1

$ErrorActionPreference = "Stop"

# --- Set SUPERPOWERS_SKILLS_ROOT environment variable ---
if (-not $HOME) { $HOME = $env:USERPROFILE }
$env:SUPERPOWERS_SKILLS_ROOT = Join-Path $HOME ".config/superpowers/skills"

# --- Resolve script and plugin root directories ---
# $PSScriptRoot is available when run from a file; fall back if needed.
$scriptPath = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$pluginRoot = (Resolve-Path (Join-Path $scriptPath "..")).Path

# --- Run skills initialization script (clone/fetch/auto-update) ---
$initOutput = ""
try {
    $initOutput = & (Join-Path $pluginRoot "lib/InitializeSkills.ps1") 2>&1
} catch {
    # Match bash behavior of swallowing errors for init
    $initOutput = ""
}

# --- Extract status flags and remove them from display output ---
$skillsUpdated = $false
$skillsBehind  = $false

if ($initOutput) {
    $skillsUpdated = [bool]([string]$initOutput | Select-String -SimpleMatch "SKILLS_UPDATED=true" -Quiet)
    $skillsBehind  = [bool]([string]$initOutput | Select-String -SimpleMatch "SKILLS_BEHIND=true" -Quiet)

    $initDisplayLines = ($initOutput -split "`r?`n") | Where-Object {
        $_ -notmatch "SKILLS_UPDATED=true" -and $_ -notmatch "SKILLS_BEHIND=true"
    }
    $initDisplay = ($initDisplayLines -join "`n").TrimEnd()
} else {
    $initDisplay = ""
}

# --- Run find-skills to show all available skills ---
$findSkillsPath = Join-Path $pluginRoot "lib/FindSkills.ps1"
$findSkillsOutput = ""
try {
    $findSkillsOutput = & (Join-Path $pluginRoot "lib/FindSkills.ps1") -ErrorAction SilentlyContinue -ScriptDir "$env:SUPERPOWERS_SKILLS_ROOT" 2>&1
} catch {
    $findSkillsOutput = "Error running find-skills."
}

# --- Read using-skills content (renamed from getting-started) ---
$usingSkillsPath = Join-Path $env:SUPERPOWERS_SKILLS_ROOT "skills/using-skills/SKILL.md"
$usingSkillsContent = ""
try {
    $usingSkillsContent = Get-Content -LiteralPath $usingSkillsPath -Raw -ErrorAction Stop
} catch {
    $usingSkillsContent = "Error reading using-skills"
}

# --- Build initialization/status messages (as plain text; JSON escaping handled later) ---
$initMessage = if ([string]::IsNullOrWhiteSpace($initDisplay)) { "" } else { "$initDisplay`n`n" }
$statusMessage = if ($skillsBehind) {
    "`n`n⚠️ New skills available from upstream. Ask me to use the pulling-updates-from-skills-repository skill."
} else {
    ""
}

# --- Compose the additionalContext block (plain text) ---
$toolFindPath = Join-Path $env:SUPERPOWERS_SKILLS_ROOT "skills/using-skills/find-skills"
$toolRunPath  = Join-Path $env:SUPERPOWERS_SKILLS_ROOT "skills/using-skills/skill-run"
$skillsHome   = Join-Path $env:SUPERPOWERS_SKILLS_ROOT "skills/"

$additionalContextPlain = @"
<EXTREMELY_IMPORTANT>
You have superpowers.

$initMessage

**The content below is from skills/using-skills/SKILL.md - your introduction to using skills:**

$usingSkillsContent

**Tool paths (use these when you need to search for or run skills):**
- find-skills: $toolFindPath
- skill-run: $toolRunPath

**Skills live in:** $skillsHome (you work on your own branch and can edit any skill)

**Available skills (output of find-skills):**

$findSkillsOutput 
---
$statusMessage

</EXTREMELY_IMPORTANT>
"@

# --- Emit context injection as JSON ---
# Let PowerShell handle all JSON escaping properly.
$payload = @{
    hookSpecificOutput = @{
        hookEventName     = "SessionStart"
        additionalContext = $additionalContextPlain
        suppressOutput = $false
	    systemMessage = "Superpowers plugin loaded."
    }
}

$payload | ConvertTo-Json -Depth 6
#[void](Read-Host "Press enter to continue")
exit 0