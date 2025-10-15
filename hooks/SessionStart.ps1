<# 
  SessionStart hook for superpowers plugin (PowerShell version)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$pluginPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path -replace '\\', '/'
$skillsPath = (Resolve-Path (Join-Path $HOME '.config\superpowers\skills\skills')).Path -replace '\\', '/'


# --- Compose additionalContext and emit JSON --------------------------------

$additionalContext = @"
Superpowers plugin active (ScriptPro-specific version)

You have either just started, or executed an operation that cleared your context.  To make use of the plugin you should run the /superpowers:reload command now.

Plugin Path: $pluginPath
Skills Path: $skillsPath
"@

$payload = [pscustomobject]@{
    hookSpecificOutput = [pscustomobject]@{
        hookEventName     = "SessionStart"
        additionalContext = $additionalContext
    }
}

$payload | ConvertTo-Json -Depth 6
exit 0