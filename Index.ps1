#Requires -Version 7
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'DumplingsDefaultParameterValues', Justification = 'Shared across scripts')]

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
    Position = 1,
    HelpMessage = 'The path containing tasks'
  )]
  [string]
  $Path = (Join-Path $PSScriptRoot 'Tasks'),

  [Parameter(
    Position = 2,
    HelpMessage = 'Do not skip tasks even if they are meant to be skipped'
  )]
  [switch]
  $NoSkip = $false,

  [Parameter(
    Position = 3,
    HelpMessage = 'Skip checking states'
  )]
  [switch]
  $NoCheck = $false,

  [Parameter(
    Position = 4,
    HelpMessage = 'Skip writing states'
  )]
  [switch]
  $NoWrite = $false,

  [Parameter(
    Position = 5,
    HelpMessage = 'Skip sending messages'
  )]
  [switch]
  $NoMessage = $false,

  [Parameter(
    Position = 6,
    HelpMessage = 'Skip creating manifests'
  )]
  [switch]
  $NoSubmit = $false,

  [Parameter(
    Position = 7,
    HelpMessage = 'The number of threads to use concurrently'
  )]
  [ValidateScript({ $_ -gt 0 }, ErrorMessage = 'The number should be positive.')]
  [int]
  $ThrottleLimit = 8,

  [Parameter(
    DontShow, Position = 8,
    HelpMessage = 'Tell the script it is running in a thread to skip some regions'
  )]
  [switch]
  $Parallel = $false,

  [Parameter(
    DontShow, Position = 9,
    HelpMessage = 'Tell the script which thread it is'
  )]
  [int]
  $WokID = 0
)

# Enable strict mode to avoid non-existent or empty properties from the API
# Set-StrictMode -Version 3.0

# Hide the progress bar
if (Test-Path -Path Env:\CI) {
  $ProgressPreference = 'SilentlyContinue'
}

# Set default parameter values for libraries
$PSDefaultParameterValues = $Global:DumplingsDefaultParameterValues = @{
  'Invoke-WebRequest:TimeoutSec'        = 30
  'Invoke-WebRequest:MaximumRetryCount' = 3
  'Invoke-WebRequest:RetryIntervalSec'  = 5
  'Invoke-RestMethod:TimeoutSec'        = 30
  'Invoke-RestMethod:MaximumRetryCount' = 3
  'Invoke-RestMethod:RetryIntervalSec'  = 5
}

if (-not $Parallel) {
  # Set console input and output encoding to UTF-8
  $OldOutputEncoding = [System.Console]::OutputEncoding
  $OldInputEncoding = [System.Console]::InputEncoding
  [System.Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(65001)
  [System.Console]::InputEncoding = [System.Text.Encoding]::GetEncoding(65001)

  # Remove related jobs to avoid conflicts
  Get-Job | Where-Object -FilterScript { $_.Name.StartsWith('Dumplings') } | Remove-Job -Force

  # Install and import required PowerShell modules
  $InstalledModulesNames = Get-Package | Select-Object -ExpandProperty Name
  @('PowerHTML', 'powershell-yaml') | ForEach-Object -Process {
    if ($InstalledModulesNames -notcontains $_) {
      Write-Host -Object "`e[1mDumplings:`e[22m Installing PowerShell module ${_}"
      Install-Package -Name $_ -Source PSGallery -ProviderName PowerShellGet -Force | Out-Null
      Write-Host -Object "`e[1mDumplings:`e[22m PowerShell module ${_} is installed"
    }
  }

  # Import libraries
  Join-Path $PSScriptRoot 'Libraries' | Get-ChildItem -Include '*.psm1' -Recurse -File | Import-Module -Force

  # Queue tasks to load
  $TaskNames = $Name ?? (Get-ChildItem -Path $Path -Directory | Select-Object -ExpandProperty Name)
  Write-Host -Object "`e[1mDumplings:`e[22m $($TaskNames.Count ?? 0) task(s) to load"

  # Set up temp storage for tasks
  $Global:LocalStorage = [ordered]@{}

  # Set up temp folder for tasks
  $Global:LocalCache = (New-Item -Path $PSScriptRoot -Name 'Outputs' -ItemType Directory -Force).FullName
  Get-ChildItem $LocalCache | Remove-Item -Recurse -Force

  # Start multiple threads jobs and run tasks in them if the limit is greater than 1, otherwise run tasks in current thread
  if ($ThrottleLimit -gt 1) {
    # Run Start-ThreadJob once to set the throttle limit
    Start-ThreadJob -ScriptBlock {} -ThrottleLimit $ThrottleLimit | Wait-Job | Out-Null

    $Jobs = @()
    foreach ($i in 0..($ThrottleLimit - 1)) {
      $Jobs += Start-ThreadJob -FilePath $MyInvocation.MyCommand.Definition -Name "DumplingsWok${i}" -StreamingHost $Host -ArgumentList @(
        $Name, $Path, $NoSkip, $NoCheck, $NoWrite, $NoMessage, $NoSubmit, $ThrottleLimit, $true, $i
      )
    }
  }
}

# Run tasks in thread jobs if the limit is greater than 1, otherwise run tasks in current thread
if ($Parallel -or $ThrottleLimit -eq 1) {
  # Set up parameters for threads
  $ScriptRoot = $Parallel ? $using:PSScriptRoot : $PSScriptRoot
  if ($Parallel) {
    $TaskNames = $using:TaskNames
    $Global:LocalStorage = $using:LocalStorage
    $Global:LocalCache = $using:LocalCache
  }

  # Import libraries
  Join-Path $ScriptRoot 'Libraries' | Get-ChildItem -Include '*.psm1' -Recurse -File | Import-Module

  # Import models
  Join-Path $ScriptRoot 'Models' | Get-ChildItem -Include '*.ps1' -Recurse -File | ForEach-Object -Process { . $_ }

  # Load tasks
  $Tasks = @()
  $Index = (0..(($TaskNames).Count - 1)).Where({ ($_ % $ThrottleLimit) -eq $WokID })
  $FilteredTaskNames = (($TaskNames)[$Index])
  foreach ($TaskName in $FilteredTaskNames) {
    try {
      $TaskPath = Join-Path $Path $TaskName -Resolve
      $TaskConfigPath = Join-Path $TaskPath 'Config.yaml' -Resolve
      $TaskConfig = Get-Content -Path $TaskConfigPath -Raw | ConvertFrom-Yaml -Ordered
      $Task = New-Object -TypeName $TaskConfig.Type -ArgumentList @{
        Name       = $TaskName
        Path       = $TaskPath
        ConfigPath = $TaskConfigPath
        Config     = $TaskConfig
        Preference = @{
          NoSkip    = $NoSkip
          NoCheck   = $NoCheck
          NoWrite   = $NoWrite
          NoMessage = $NoMessage
          NoSubmit  = $NoSubmit
        }
      }
      $Tasks += $Task
    } catch {
      Write-Log -Object "`e[1mDumplingsWok${WokID}:`e[22m Failed to initialize task ${TaskName}:" -Level Error
      $_ | Out-Host
    }
  }
  Write-Log -Object "`e[1mDumplingsWok${WokID}:`e[22m $($Tasks.Count) task(s) loaded, $($FilteredTaskNames.Count - $Tasks.Count) task(s) not loaded"

  # Invoke tasks
  foreach ($Task in $Tasks) {
    try {
      $Task.Invoke()
    } catch {
      Write-Log -Object "`e[1mDumplingsWok${WokID}:`e[22m An error occured while running the script for $($Task.Name):" -Level Error
      $_ | Out-Host
    }
  }

  Write-Log -Object "`e[1mDumplingsWok${WokID}:`e[22m Done" -Level Verbose

  # Clean environment
  if ($Parallel) { Get-Module | Where-Object -FilterScript { $_.Path.Contains($using:PSScriptRoot) } | Remove-Module }
}

if (-not $Parallel) {
  if ($ThrottleLimit -gt 1) {
    # Wait until all jobs are done
    $Jobs | Wait-Job -Timeout 3600 | Receive-Job

    # Check if all jobs are still running or not
    if (Get-Job -State Running) {
      Write-Log -Object "`e[1mDumplings:`e[22m Some jobs didn't complete in time and will be stopped"
      Get-Job -State Running | Out-Host
    }
  }

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
  # Set-StrictMode -Off

  # Restore original console input and output encoding
  [System.Console]::OutputEncoding = $OldOutputEncoding
  [System.Console]::InputEncoding = $OldInputEncoding
}
