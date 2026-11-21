#Requires -Version 7.4
<#
.SYNOPSIS
  Benchmark isolated imports, synthetic runner graphs, manifest updates, or static parsers.
.PARAMETER RepositoryPath
  Checkout to measure, allowing the same harness to compare a baseline checkout.
.PARAMETER Samples
  Number of independent processes per workload.
.PARAMETER WorkerCount
  Worker counts for runner workloads; defaults to one and four.
.PARAMETER Scenario
  Workloads to run. Parser requires an explicit local fixture and Get-*Info command.
.PARAMETER InstallerPath
  Optional trusted static fixture. It is never executed.
.PARAMETER ParserCommand
  Public Get-*Info function for static fixture analysis.
.PARAMETER OutputPath
  JSON measurement artifact. Temporary roots and child output are removed afterward.
#>
param (
  [string]$RepositoryPath = (Join-Path $PSScriptRoot '..' '..'),
  [ValidateRange(1, 20)][int]$Samples = 3,
  [int[]]$WorkerCount = @(1, 4),
  [ValidateSet('Import', 'Independent', 'Dependencies', 'Manifest', 'Parser')][string[]]$Scenario = @('Import', 'Independent', 'Dependencies', 'Manifest'),
  [string]$InstallerPath,
  [ValidatePattern('^Get-[A-Za-z0-9]+Info$')][string]$ParserCommand,
  [string]$OutputPath = (Join-Path $PWD 'Outputs' 'benchmark.json')
)
$ErrorActionPreference = 'Stop'
$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).ProviderPath
if ('Parser' -in $Scenario -and (-not $InstallerPath -or -not $ParserCommand)) { throw 'Parser benchmarking requires InstallerPath and ParserCommand.' }
if ($InstallerPath) { $InstallerPath = (Resolve-Path -LiteralPath $InstallerPath).ProviderPath }
$Root = [IO.Directory]::CreateTempSubdirectory('Dumplings-Benchmark-').FullName
$Results = [Collections.Generic.List[object]]::new()
try {
  foreach ($Workload in $Scenario) {
    $Counts = if ($Workload -in 'Independent', 'Dependencies') { $WorkerCount } else { @(1) }
    foreach ($Workers in $Counts) {
      if ($Workers -lt 1) { throw 'WorkerCount must be positive.' }
      for ($Sample = 1; $Sample -le $Samples; $Sample++) {
        $Case = New-Item (Join-Path $Root "$Workload-$Workers-$Sample") -ItemType Directory
        $ResultPath = Join-Path $Case 'result.json'
        if ($Workload -in 'Independent', 'Dependencies') {
          # Older coordinators resolve worker libraries from the working root.
          # Copy Core outside the timed interval so both revisions see that layout.
          $CoreCopy = New-Item (Join-Path $Case 'Core') -ItemType Directory
          Get-ChildItem -LiteralPath (Join-Path $RepositoryPath 'Core') -Exclude '.git', 'Tests' | Copy-Item -Destination $CoreCopy -Recurse
          $Module = New-Item (Join-Path $Case 'Modules' 'Probe') -ItemType Directory -Force
          Set-Content (Join-Path $Case 'Preference.yaml') 'Timeout: 60'
          Set-Content (Join-Path $Module 'Index.ps1') @'
class BenchmarkTask {
  [string]$Name
  [Collections.IDictionary]$Config
  [bool]$InvocationSucceeded
  [bool]$InvocationSkipped
  BenchmarkTask([Collections.IDictionary]$Properties) { $this.Name = $Properties.Name; $this.Config = $Properties.Config }
  [void] Invoke() { Start-Sleep -Milliseconds ([int]$this.Config.Delay); $this.InvocationSucceeded = $true }
  [void] Dispose() {}
}
'@
          $TaskNames = if ($Workload -eq 'Dependencies') { @('#Provider', '#Fast') + @(1..6 | ForEach-Object { "AConsumer$_" }) + @(1..9 | ForEach-Object { "ZChain$_" }) }
          else { @('#Provider') + @(1..8 | ForEach-Object { "AConsumer$_" }) + @(1..8 | ForEach-Object { "ZIndependent$_" }) }
          foreach ($TaskName in $TaskNames) {
            $TaskRoot = New-Item (Join-Path $Case 'Tasks' $TaskName) -ItemType Directory -Force
            $Config = "Type: BenchmarkTask`nDelay: $(if ($TaskName -eq '#Provider') { 700 } else { 80 })"
            if ($Workload -eq 'Dependencies' -and $TaskName.StartsWith('AConsumer')) { $Config += "`nDependsOn: ['#Provider']" }
            if ($TaskName.StartsWith('ZChain')) {
              $Position = [int]$TaskName.Substring(6)
              $Dependency = if ($Position -eq 1) { '#Fast' } else { "ZChain$($Position - 1)" }
              $Config += "`nDependsOn: ['$Dependency']"
            }
            Set-Content (Join-Path $TaskRoot 'Config.yaml') $Config
            Set-Content (Join-Path $TaskRoot 'Script.ps1') '# Synthetic delay only.'
          }
        }
        $ArgumentsPath = Join-Path $Case 'arguments.json'
        @{ Repository = $RepositoryPath; Case = $Case.FullName; Workload = $Workload; Workers = $Workers; Fixture = $InstallerPath; Parser = $ParserCommand; Result = $ResultPath } | ConvertTo-Json | Set-Content $ArgumentsPath
        $Child = @'
param($ArgumentsPath)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Arguments = Get-Content -LiteralPath $ArgumentsPath -Raw | ConvertFrom-Json
Set-Location -LiteralPath $Arguments.Case
$Watch = [Diagnostics.Stopwatch]::StartNew()
if ($Arguments.Workload -in 'Independent', 'Dependencies') {
  $Tasks = @(& (Join-Path $Arguments.Repository 'Core' 'Index.ps1') -ThrottleLimit $Arguments.Workers -PassThru)
  if ($Tasks.Count -ne 17 -or @($Tasks | Where-Object { -not $_.InvocationSucceeded }).Count) { throw 'The benchmark did not execute all 17 synthetic tasks successfully.' }
} else {
  Import-Module PowerHTML, powershell-yaml
  Import-Module (Join-Path $Arguments.Repository 'Modules' 'PackageModule' 'PackageModule.psd1')
  if ($Arguments.Workload -eq 'Manifest') {
    $Model = New-WinGetManifestModel -PackageIdentifier 'Example.Benchmark' -PackageVersion '1.0' -ManifestVersion '1.12.0' -InstallerDefaults ([ordered]@{}) -Installers @([ordered]@{ Architecture = 'x64'; InstallerType = 'exe'; InstallerUrl = 'https://example.invalid/old.exe'; InstallerSha256 = ('A' * 64) }) -DefaultLocalization ([ordered]@{ PackageLocale = 'en-US'; PackageName = 'Benchmark'; Publisher = 'Example'; License = 'MIT'; ShortDescription = 'Benchmark' }) -Localizations @() -SourceFormat Memory
    $null = Update-WinGetManifest -Manifest $Model -PackageVersion '2.0' -InstallerEntries @([ordered]@{ Architecture = 'x64'; InstallerUrl = 'https://example.invalid/new.exe'; InstallerSha256 = ('B' * 64) }) -SkipInstallerAnalysis -Logger { param($Message, $Level) }
  } elseif ($Arguments.Workload -eq 'Parser') {
    $null = & $Arguments.Parser -Path $Arguments.Fixture
  }
}
$Watch.Stop()
@{ Milliseconds = $Watch.Elapsed.TotalMilliseconds; PeakWorkingSetBytes = [Diagnostics.Process]::GetCurrentProcess().PeakWorkingSet64 } | ConvertTo-Json | Set-Content -LiteralPath $Arguments.Result
'@
        $ChildPath = Join-Path $Case 'measure.ps1'
        Set-Content -LiteralPath $ChildPath $Child
        $StartInfo = [Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source)
        $StartInfo.UseShellExecute = $false
        $StartInfo.CreateNoWindow = $true
        $StartInfo.RedirectStandardOutput = $true
        $StartInfo.RedirectStandardError = $true
        foreach ($Argument in '-NoProfile', '-NonInteractive', '-File', $ChildPath, $ArgumentsPath) { $StartInfo.ArgumentList.Add($Argument) }
        $Process = [Diagnostics.Process]::Start($StartInfo)
        try {
          $Stdout = $Process.StandardOutput.ReadToEndAsync()
          $Stderr = $Process.StandardError.ReadToEndAsync()
          if (-not $Process.WaitForExit(180000)) { $Process.Kill($true); throw 'Benchmark child timed out.' }
          if ($Process.ExitCode) { throw "Benchmark child failed: $($Stderr.GetAwaiter().GetResult()) $($Stdout.GetAwaiter().GetResult())" }
          $Measurement = Get-Content -LiteralPath $ResultPath -Raw | ConvertFrom-Json
          $Results.Add([pscustomobject]@{ Scenario = $Workload; Workers = $Workers; Sample = $Sample; Milliseconds = $Measurement.Milliseconds; PeakWorkingSetBytes = $Measurement.PeakWorkingSetBytes })
        } finally { $Process.Dispose() }
      }
    }
  }
  $OutputPath = [IO.Path]::GetFullPath($OutputPath, $PWD.Path)
  $null = New-Item ([IO.Path]::GetDirectoryName($OutputPath)) -ItemType Directory -Force
  $Results.ToArray() | ConvertTo-Json | Set-Content -LiteralPath $OutputPath
  $Results.ToArray()
} finally {
  # Root is the absolute directory returned by CreateTempSubdirectory, never caller input.
  Remove-Item -LiteralPath $Root -Recurse -Force -ErrorAction Continue
}
