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
.PARAMETER ThrottleLimit
  The number of threads to use concurrently
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
  $NoSubmit = $false,

  [Parameter(
    HelpMessage = 'The number of threads to use concurrently'
  )]
  [ValidateScript({ $_ -gt 0 }, ErrorMessage = 'The number should be positive.')]
  [int]
  $ThrottleLimit = 5
)

# Set console input and output encoding to UTF-8
$OldOutputEncoding = [System.Console]::OutputEncoding
$OldInputEncoding = [System.Console]::InputEncoding
[System.Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(65001)
[System.Console]::InputEncoding = [System.Text.Encoding]::GetEncoding(65001)

# Restore original console input and output encoding when an error occured
# trap {
#   $_ | Out-Host
#   [System.Console]::OutputEncoding = $OldOutputEncoding
#   [System.Console]::InputEncoding = $OldInputEncoding
#   exit
# }

# Hide the progress bar
if ($Env:CI) {
  $ProgressPreference = 'SilentlyContinue'
}

# Install and import required PowerShell modules
$InstalledModulesNames = Get-Package | Select-Object -ExpandProperty Name
@('PowerHTML', 'powershell-yaml') | ForEach-Object -Process {
  if ($InstalledModulesNames -notcontains $_) {
    Write-Host -Object "`e[1mDumplings:`e[22m Installing PowerShell module ${_}"
    Install-Package -Name $_ -Source PSGallery -ProviderName PowerShellGet -Force | Out-Null
    Write-Host -Object "`e[1mDumplings:`e[22m PowerShell module ${_} is installed"
  }
}

# Remove related jobs to avoid conflicts
Get-Job | Where-Object -FilterScript { $_.Name.StartsWith('Dumplings') } | Remove-Job -Force

# Import libraries
Join-Path $PSScriptRoot 'Libraries' 'General.psm1' | Import-Module -Force

# Queue tasks to load
$TaskNames = $Name ?? (Get-ChildItem -Path $Path -Directory | Select-Object -ExpandProperty Name)
Write-Log -Object "`e[1mDumplings:`e[22m $($TaskNames.Count ?? 0) task(s) to load"

# Temp storage for tasks
$LocalStorage = [ordered]@{}

# Temp folder for tasks
$LocalCache = (New-Item -Path $Env:TEMP -Name 'Dumplings' -ItemType Directory -Force).FullName

$Jobs = @()
foreach ($i in 0..($ThrottleLimit - 1)) {
  $Jobs += Start-ThreadJob -Name "DumplingsWok${i}" -StreamingHost $Host -ScriptBlock {
    # Enable strict mode to avoid non-existent or empty properties from the API
    # Set-StrictMode -Version 3.0

    # Set default parameter values for libraries
    $PSDefaultParameterValues = $Global:DumplingsDefaultParameterValues = @{
      'Invoke-WebRequest:TimeoutSec'        = 30
      'Invoke-WebRequest:MaximumRetryCount' = 3
      'Invoke-WebRequest:RetryIntervalSec'  = 5
      'Invoke-RestMethod:TimeoutSec'        = 30
      'Invoke-RestMethod:MaximumRetryCount' = 3
      'Invoke-RestMethod:RetryIntervalSec'  = 5
    }

    # Hide the progress bar
    if (Test-Path -Path Env:\CI) {
      $ProgressPreference = 'SilentlyContinue'
    }

    # Import libraries
    Join-Path $using:PSScriptRoot 'Libraries' | Get-ChildItem -Include '*.psm1' -Recurse -File | Import-Module -Force

    # Import models
    Join-Path $using:PSScriptRoot 'Models' | Get-ChildItem -Include '*.ps1' -Recurse -File | ForEach-Object -Process { . $_ }

    # Load tasks
    $Tasks = @()
    $Index = (0..(($using:TaskNames).Count - 1)).Where({ ($_ % $using:ThrottleLimit) -eq $using:i })
    $FilteredTaskNames = (($using:TaskNames)[$Index])
    foreach ($TaskName in $FilteredTaskNames) {
      try {
        $TaskPath = Join-Path $using:Path $TaskName -Resolve
        $TaskConfigPath = Join-Path $TaskPath 'Config.yaml' -Resolve
        $TaskConfig = Get-Content -Path $TaskConfigPath -Raw | ConvertFrom-Yaml
        $Task = New-Object -TypeName $TaskConfig.Type -ArgumentList @{
          Name       = $TaskName
          Path       = $TaskPath
          ConfigPath = $TaskConfigPath
          Config     = $TaskConfig
          Preference = @{
            NoSkip    = $using:NoSkip
            NoCheck   = $using:NoCheck
            NoWrite   = $using:NoWrite
            NoMessage = $using:NoMessage
            NoSubmit  = $using:NoSubmit
          }
        }
        $Tasks += $Task
      } catch {
        Write-Log -Object "`e[1mDumplingsWok${using:i}:`e[22m Failed to initialize task ${TaskName}:" -Level Error
        $_ | Out-Host
      }
    }
    Write-Log -Object "`e[1mDumplingsWok${using:i}:`e[22m $($Tasks.Count) task(s) loaded, $($FilteredTaskNames.Count - $Tasks.Count) task(s) not loaded"

    # Temp storage for tasks
    $Global:LocalStorage = $using:LocalStorage

    # Temp folder for tasks
    $Global:LocalCache = $using:LocalCache

    # Invoke tasks
    foreach ($Task in $Tasks) {
      try {
        $Task.Invoke()
      } catch {
        Write-Log -Object "`e[1mDumplingsWok${using:i}:`e[22m An error occured while running the script for $($Task.Name):" -Level Error
        $_ | Out-Host
      }
    }

    Write-Log -Object "`e[1mDumplingsWok${using:i}:`e[22m Done"

    # Clean environment
    Get-Module | Where-Object -FilterScript { $_.Path.Contains($PSScriptRoot) } | Remove-Module
    # Set-StrictMode -Off
  }.GetNewClosure()
}

# Wait until all jobs are done
$Jobs | Wait-Job | Out-Null

if (Test-Path -Path Env:\CI) {
  if (-not [string]::IsNullOrWhiteSpace((git ls-files --other --modified --exclude-standard $Path))) {
    Write-Log -Object "`e[1mDumplings:`e[22m Committing and pushing changes" -Level Info
    git config user.name 'github-actions[bot]'
    git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
    git pull
    git add $Path
    git commit -m "Automation: Update states [$env:GITHUB_RUN_NUMBER]"
    git push
  } else {
    Write-Log -Object "`e[1mDumplings:`e[22m No changes to commit" -Level Info
  }
}

# Clean environment
Get-Module | Where-Object -FilterScript { $_.Path.Contains($PSScriptRoot) } | Remove-Module
Get-Job | Where-Object -FilterScript { $_.Name.StartsWith('Dumplings') } | Remove-Job -Force

# Restore original console input and output encoding
[System.Console]::OutputEncoding = $OldOutputEncoding
[System.Console]::InputEncoding = $OldInputEncoding
