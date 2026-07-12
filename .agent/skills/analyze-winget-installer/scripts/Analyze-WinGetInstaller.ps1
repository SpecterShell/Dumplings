<#
.SYNOPSIS
  Compatibility wrapper for the PackageModule WinGet installer analyzer.
.DESCRIPTION
  The analyzer implementation lives in Modules\PackageModule\Libraries\WinGetInstallerAnalyzer.psm1.
  This script only loads PackageModule for ad-hoc skill usage and serializes the returned object as JSON.
.PARAMETER Path
  The installer path to inspect.
.PARAMETER RepoRoot
  The Dumplings repository root. If omitted, the script walks upward from this file.
.PARAMETER DetectorTimeoutSeconds
  Deprecated. The PackageModule analyzer runs detectors in-process.
.PARAMETER ScanBytes
  Total byte budget used for bounded multi-window string heuristics.
.PARAMETER ExtractEmbeddedMsi
  For Advanced Installer, also try static extraction of embedded MSI metadata.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory, Position = 0)]
  [string]$Path,

  [string]$RepoRoot,

  [ValidateRange(1, 300)]
  [int]$DetectorTimeoutSeconds = 30,

  [ValidateRange(4096, 268435456)]
  [int64]$ScanBytes = 16777216,

  [switch]$ExtractEmbeddedMsi
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Resolve-DumplingsRoot {
  param([string]$StartPath)

  $Current = Get-Item -LiteralPath $StartPath -Force
  if (-not $Current.PSIsContainer) { $Current = $Current.Directory }

  while ($Current) {
    $PackageModulePath = Join-Path $Current.FullName 'Modules\PackageModule\Index.ps1'
    if (Test-Path -LiteralPath $PackageModulePath) { return $Current.FullName }
    $Current = $Current.Parent
  }

  throw 'Unable to locate the Dumplings repository root.'
}

if (-not $RepoRoot) {
  $RepoRoot = Resolve-DumplingsRoot -StartPath $PSScriptRoot
}

if ($PSBoundParameters.ContainsKey('DetectorTimeoutSeconds')) {
  Write-Warning 'DetectorTimeoutSeconds is deprecated for the PackageModule analyzer wrapper; detectors run in-process.'
}

Import-Module (Join-Path $RepoRoot 'Modules\PackageModule\Index.ps1') -Force
Get-WinGetInstallerAnalysis -Path $Path -ScanBytes $ScanBytes -ExtractEmbeddedMsi:$ExtractEmbeddedMsi.IsPresent | ConvertTo-Json -Depth 30
