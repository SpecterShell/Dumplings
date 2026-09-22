#Requires -Version 7.4
<#
.SYNOPSIS
  Run a component's offline unit tests or its complete fixture-enabled suite.
.PARAMETER Component
  Repository whose tests run in this PowerShell process.
.PARAMETER Offline
  Select explicit Unit groups in parser submodules and prohibit fixture downloads.
  Core's entire suite uses synthetic task roots and can always run offline.
#>
param ([Parameter(Mandatory)][ValidateSet('Core', 'PackageModule', 'InstallerParsers')][string]$Component, [switch]$Offline)
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' '..'))
$TestPath = if ($Component -eq 'Core') { Join-Path $Root 'Core' 'Tests' } else { Join-Path $Root 'Modules' $Component 'Tests' }
$Output = New-Item -Path (Join-Path $Root 'Outputs' 'Tests') -ItemType Directory -Force
$OldOffline = $env:DUMPLINGS_TEST_OFFLINE
$OldFixtureRoot = $env:DUMPLINGS_TEST_FIXTURE_ROOT
$TemporaryFixtures = $null
try {
  if ($Offline) {
    $env:DUMPLINGS_TEST_OFFLINE = '1'
    if (-not $OldFixtureRoot) {
      $TemporaryFixtures = [IO.Directory]::CreateTempSubdirectory('Dumplings-Offline-').FullName
      $env:DUMPLINGS_TEST_FIXTURE_ROOT = $TemporaryFixtures
    }
  }
  Import-Module Pester -MinimumVersion 6.2.0
  $Configuration = New-PesterConfiguration
  $Configuration.Run.Path = $TestPath
  $Configuration.Run.PassThru = $true
  $Configuration.TestResult.Enabled = $true
  $Configuration.TestResult.OutputPath = Join-Path $Output "$Component.xml"
  if ($Offline -and $Component -ne 'Core') { $Configuration.Filter.Tag = @('Unit') }
  $Configuration.Filter.ExcludeTag = if ($Offline) { @('Live', 'RealFixture') } else { @('Live') }
  $Result = Invoke-Pester -Configuration $Configuration
  if ($Result.FailedCount -or $Result.FailedContainersCount -or $Result.PassedCount -eq 0) { throw "$Component regression tests failed or no tests ran." }
} finally {
  $env:DUMPLINGS_TEST_OFFLINE = $OldOffline
  $env:DUMPLINGS_TEST_FIXTURE_ROOT = $OldFixtureRoot
  if ($TemporaryFixtures) { Remove-Item -LiteralPath $TemporaryFixtures -Recurse -Force }
}
