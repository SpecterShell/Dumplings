#Requires -Version 7

<#
.SYNOPSIS
  Run tests on tasks, regardless of skipping mode and comparison status
.PARAMETER Name
  The name of the tasks to be tested. Leave blank to test all tasks
.PARAMETER Path
  The path containing tasks
.PARAMETER NoSkip
  Do not skip tasks
.PARAMETER NoCheck
  Skip checking states
.PARAMETER NoWrite
  Skip writing states
.PARAMETER NoMessage
  Skip sending messages
.PARAMETER NoSubmit
  Skip creating manifest
.EXAMPLE
  .\Test.ps1
  Run tests on all tasks
.EXAMPLE
  .\Test.ps1 -Name '115.115'
  Run tests on task "115.115"
#>
[CmdletBinding()]
param (
  [Parameter(
    ValueFromPipeline, Position = 0,
    HelpMessage = 'The name of the tasks to be tested. Leave blank to test all tasks'
  )]
  [ArgumentCompleter({ Get-ChildItem -Path ($args[4].Path ?? (Join-Path $PSScriptRoot 'Tasks')) -Include "$($args[2])*" -Recurse -Directory | Select-Object -ExpandProperty 'Name' })]
  [string[]]
  $Name,

  [Parameter(
    HelpMessage = 'The path containing tasks'
  )]
  [string]
  $Path = (Join-Path $PSScriptRoot 'Tasks'),

  [Parameter(
    HelpMessage = 'Do not skip tasks even if they are meant to be skipped'
  )]
  [switch]
  $NoSkip = $false,

  [Parameter(
    HelpMessage = 'Skip checking states'
  )]
  [switch]
  $NoCheck = $false,

  [Parameter(
    HelpMessage = 'Skip writing states'
  )]
  [switch]
  $NoWrite = $false,

  [Parameter(
    HelpMessage = 'Skip sending messages'
  )]
  [switch]
  $NoMessage = $false,

  [Parameter(
    HelpMessage = 'Skip creating manifests'
  )]
  [switch]
  $NoSubmit = $false
)

# Set console input and output encoding to UTF-8
$Private:OldOutputEncoding = [System.Console]::OutputEncoding
$Private:OldInputEncoding = [System.Console]::InputEncoding
[System.Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(65001)
[System.Console]::InputEncoding = [System.Text.Encoding]::GetEncoding(65001)

# Hide the progress bar of Invoke-WebRequest
if ([console]::IsOutputRedirected -or $Env:CI) {
  $ProgressPreference = 'SilentlyContinue'
}

# Set default parameter values for libraries
$Global:DumplingsDefaultParameterValues = @{
  'Invoke-WebRequest:TimeoutSec'        = 100
  'Invoke-WebRequest:MaximumRetryCount' = 4
  'Invoke-WebRequest:RetryIntervalSec'  = 10
  'Invoke-RestMethod:TimeoutSec'        = 100
  'Invoke-RestMethod:MaximumRetryCount' = 4
  'Invoke-RestMethod:RetryIntervalSec'  = 10
}

# Install and import required PowerShell modules
$Private:InstalledModulesNames = Get-Package | Select-Object -ExpandProperty Name
@('PowerHTML', 'powershell-yaml') | ForEach-Object -Process {
  if ($InstalledModulesNames -notcontains $_) {
    Write-Host -Object "Dumplings: Installing PowerShell module ${_}"
    Install-Package -Name $_ -Source PSGallery -ProviderName PowerShellGet -Force | Out-Null
    Write-Host -Object "Dumplings: PowerShell module ${_} is installed"
  }
}

# Remove related events and event subscribers to avoid conflicts
Get-Event | Where-Object -FilterScript { $_.SourceIdentifier.StartsWith('Dumplings') } | Remove-Event

# Import libraries
Join-Path $PSScriptRoot 'Libraries' | Get-ChildItem -Include '*.psm1' -Recurse -File | Import-Module -Force

# Import models
Join-Path $PSScriptRoot 'Models' | Get-ChildItem -Include '*.ps1' -Recurse -File | ForEach-Object -Process { . $_ }

# Find tasks
$Private:Tasks = ($Name ?? (Get-ChildItem -Path $Path -Directory | Select-Object -ExpandProperty Name)) |
  ForEach-Object -Process {
    $TaskName = $_
    try {
      # Load config
      $TaskPath = Join-Path $Path $TaskName -Resolve
      $TaskConfigPath = Join-Path $TaskPath 'Config.yaml' -Resolve
      $TaskConfig = Get-Content -Path $TaskConfigPath -Raw | ConvertFrom-Yaml
      New-Object -TypeName $TaskConfig.Type -ArgumentList @{
        Name       = $TaskName
        Path       = $TaskPath
        ConfigPath = $TaskConfigPath
        Config     = $TaskConfig
        Preference = @{
          NoCheck   = $NoCheck
          NoWrite   = $NoWrite
          NoMessage = $NoMessage
          NoSubmit  = $NoSubmit
        }
      }
    } catch {
      Write-Log -Object "Dumplings: Failed to initialize task ${TaskName}:" -Level Error
      $_ | Out-Host
    }
  }
Write-Log -Object "Dumplings: $($Tasks.Length ?? 0) tasks loaded"

# Temp for tasks
$Script:Temp = [ordered]@{}

# Invoke tasks
foreach ($Task in $Tasks) {
  try {
    $Task.Invoke()
  } catch {
    Write-Log -Object "Dumplings: An error occured while running the script for $($Task.Name):" -Level Error
    $_ | Out-Host
  }
}

Start-Sleep -Seconds 5

if ($Env:CI) {
  if (-not [string]::IsNullOrWhiteSpace((git ls-files --other --modified --exclude-standard $Path))) {
    Write-Log -Object 'Dumplings: Committing and pushing changes' -Level Info
    git config user.name 'github-actions[bot]'
    git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
    git pull
    git add $Path
    git commit -m "Automation: Update states [$env:GITHUB_RUN_NUMBER]"
    git push
  } else {
    Write-Log -Object 'Dumplings: No changes to commit' -Level Info
  }
}

# Remove related events, event subscribers, libraries and variables
Get-Event | Where-Object -FilterScript { $_.SourceIdentifier.StartsWith('Dumplings') } | Remove-Event
Remove-Variable -Name DumplingsDefaultParameterValues -Scope Global

# Restore original console input and output encoding
[System.Console]::OutputEncoding = $Private:OldOutputEncoding
[System.Console]::InputEncoding = $Private:OldInputEncoding
