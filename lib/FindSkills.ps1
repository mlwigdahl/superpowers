param(
  [Parameter(Mandatory = $true)]
  [string] $ScriptDir
)

$ErrorActionPreference = 'Stop'

try {
  $SkillsDir = (Resolve-Path -LiteralPath $ScriptDir).Path
} catch {
  Write-Error "ScriptDir not found: $ScriptDir"
  exit 1
}

function Get-WhenToUse {
  param([string]$File)
  try {
    $m = Select-String -Path $File -Pattern '^\s*when_to_use:' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($m) { return ($m.Line -replace '^\s*when_to_use:\s*','').Trim() }
    return ''
  } catch { return '' }
}

function Get-SkillPath {
  param([string]$File, [string]$BaseDir)
  $full = [IO.Path]::GetFullPath($File)
  $base = [IO.Path]::GetFullPath($BaseDir)
  $rel  = if ($full.StartsWith($base, $true, [Globalization.CultureInfo]::InvariantCulture)) {
    $full.Substring($base.Length).TrimStart('\','/')
  } else { $full }
  ($rel -replace '\\','/')
}

# Collect all SKILL.md files
$files = Get-ChildItem -Path $SkillsDir -Recurse -Filter 'SKILL.md' -File -ErrorAction SilentlyContinue |
         Select-Object -ExpandProperty FullName

#Write-Object $files
#exit 0

if (-not $files -or $files.Count -eq 0) {
  Write-Output "❌ No skills found"
  exit 0
}

# Build, sort, and display results
$results = foreach ($file in $files) {
  $path = Get-SkillPath -File $file -BaseDir $SkillsDir
  $when = Get-WhenToUse -File $file
  [pscustomobject]@{ Path = $path; When = $when }
}

$results |
  Sort-Object Path |
  ForEach-Object {
    if ([string]::IsNullOrWhiteSpace($_.When)) { "$($_.Path)" }
    else { "Use $($_.Path) $($_.When)" }
  }