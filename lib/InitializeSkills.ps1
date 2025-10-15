#Requires -Version 5.1
<#
    setup-skills.ps1 (PowerShell 5.1 compatible)
    - Fast-forwards if repo already exists
    - Otherwise initializes repo, optionally forks with GitHub CLI, and adds upstream
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Config ---
$SkillsDir  = Join-Path $HOME ".config/superpowers/skills"
$SkillsRepo = "https://github.com/obra/superpowers-skills.git"

function Invoke-Git {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Args,
        [switch]$NoThrow
    )
    $output = & git @Args 2>$null
    $exit   = $LASTEXITCODE
    if (-not $NoThrow -and $exit -ne 0) {
        throw "git $($Args -join ' ') failed with exit code $exit"
    }
    return $output
}

# If skills dir exists and is a git repo, try to fast-forward update
if (Test-Path (Join-Path $SkillsDir ".git")) {
    Push-Location $SkillsDir
    try {
        # Determine tracking remote of the current branch
        $trackingRef    = Invoke-Git -Args @('rev-parse','--abbrev-ref','--symbolic-full-name','@{u}') -NoThrow | Select-Object -First 1
        $trackingRemote = if ($trackingRef) { $trackingRef.Split('/')[0] } else { '' }

        # Fetch from tracking remote if set; otherwise try upstream then origin
        if ($trackingRemote) {
            Invoke-Git -Args @('fetch', $trackingRemote) -NoThrow | Out-Null
        } else {
            $fetched = $false
            if (-not $fetched) {
                Invoke-Git -Args @('fetch','upstream') -NoThrow | Out-Null
                if ($LASTEXITCODE -eq 0) { $fetched = $true }
            }
            if (-not $fetched) {
                Invoke-Git -Args @('fetch','origin') -NoThrow | Out-Null
            }
        }

        # Capture local/remote/base commit IDs (non-throwing; empty if not available)
        $local  = Invoke-Git -Args @('rev-parse','@')     -NoThrow | Select-Object -First 1
        $remote = Invoke-Git -Args @('rev-parse','@{u}')  -NoThrow | Select-Object -First 1
        $base   = Invoke-Git -Args @('merge-base','@','@{u}') -NoThrow | Select-Object -First 1

        if ($local -and $remote -and ($local -ne $remote)) {
            if ($local -eq $base) {
                Write-Host "Updating skills to latest version..."
                try {
                    Invoke-Git -Args @('merge','--ff-only','@{u}') | Out-Host
                    Write-Host "✓ Skills updated successfully"
                    Write-Output "SKILLS_UPDATED=true"
                } catch {
                    Write-Host "Failed to update skills"
                }
            }
            elseif ($remote -ne $base) {
                # Local behind or diverged (cannot fast-forward)
                Write-Output "SKILLS_BEHIND=true"
            }
            # If $remote -eq $base, local is ahead — no action needed
        }
    } finally {
        Pop-Location
    }
    exit 0
}

# --- Initialize (repo not present) ---
Write-Host "Initializing skills repository..."

# Handle migration from old installation
$oldConfig = Join-Path $HOME ".config/superpowers"
$oldGitDir = Join-Path $oldConfig ".git"
if (Test-Path $oldGitDir) {
    Write-Host "Found existing installation. Backing up..."
    $bakGitDir = Join-Path $oldConfig ".git.bak"
    Move-Item -Force $oldGitDir $bakGitDir

    $oldSkills = Join-Path $oldConfig "skills"
    if (Test-Path $oldSkills) {
        $bakSkills = Join-Path $oldConfig "skills.bak"
        Move-Item -Force $oldSkills $bakSkills
        Write-Host "Your old skills are in ~/.config/superpowers/skills.bak"
    }
}

# Clone the skills repository
$parentDir = Split-Path $SkillsDir -Parent
if (-not (Test-Path $parentDir)) {
    New-Item -ItemType Directory -Force -Path $parentDir | Out-Null
}
Invoke-Git -Args @('clone', $SkillsRepo, $SkillsDir) | Out-Host

Push-Location $SkillsDir
try {
    # Offer to fork if GitHub CLI is installed
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($gh) {
        Write-Host ""
        Write-Host "GitHub CLI detected. Would you like to fork superpowers-skills?"
        Write-Host "Forking allows you to share skill improvements with the community."
        Write-Host ""
        $reply = Read-Host "Fork superpowers-skills? (y/N)"
        if ($reply -match '^[Yy]$') {
            & gh repo fork obra/superpowers-skills --remote=true
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Forked! You can now contribute skills back to the community."
            } else {
                Write-Host "Fork attempt failed; adding upstream instead."
                Invoke-Git -Args @('remote','add','upstream', $SkillsRepo)
            }
        } else {
            Invoke-Git -Args @('remote','add','upstream', $SkillsRepo)
        }
    } else {
        # No gh, just set up upstream remote
        Invoke-Git -Args @('remote','add','upstream', $SkillsRepo)
    }
} finally {
    Pop-Location
}

Write-Host "Skills repository initialized at $SkillsDir"