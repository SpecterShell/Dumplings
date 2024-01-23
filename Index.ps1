<#
.SYNOPSIS
  A bootstrapping script to build and run tasks, in either single-thread mode or multi-threads mode
.PARAMETER Name
  The names of the tasks to run. Leave blank to run all tasks
.PARAMETER Path
  The path to the folder containing the task files
.PARAMETER ThrottleLimit
  The number of workers used to run the tasks concurrently in multi-threads mode. Set it to 1 to run in single-thread mode
.PARAMETER Params
  Additional parameters to be passed to the model instances
.EXAMPLE
  .\Index.ps1
  Run all the tasks in the default directory (The 'Tasks' folder in the same directory as the script)
.EXAMPLE
  .\Index.ps1 -Name 'A', 'B'
  Run tasks "A" and "B" in the default directory
.EXAMPLE
  .\Index.ps1 -Name 'A', 'B' -Path '/path/to/another/folder'
  Run tasks "A" and "B" in another directory
.EXAMPLE
  .\Index.ps1 -Name 'A', 'B' -ThrottleLimit 1
  Run tasks "A" and "B" in the default directory under single-thread mode
#>

#Requires -Version 7
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'DumplingsDefaultParameterValues', Justification = 'This variable is shared across scripts')]

[CmdletBinding()]
param (
  [Parameter(Position = 0, ValueFromPipeline, HelpMessage = 'The names of the tasks to run. Leave blank to run all tasks')]
  [ArgumentCompleter({ Get-ChildItem -Path ($args[4].Path ?? (Join-Path $PSScriptRoot 'Tasks')) -Include "$($args[2])*" -Recurse -Directory | Select-Object -ExpandProperty 'Name' })]
  [string[]]
  $Name,

  [Parameter(Position = 1, HelpMessage = 'The path to the folder containing the task files')]
  [string]
  $Path = (Join-Path $PSScriptRoot 'Tasks'),

  [Parameter(Position = 2, HelpMessage = 'The number of workers used to run the tasks concurrently in multi-threads mode. Set it to 1 to run in single-thread mode')]
  [ValidateScript({ $_ -gt 0 }, ErrorMessage = 'The number should be positive.')]
  [ushort]
  $ThrottleLimit = 1,

  [Parameter(Position = 3, DontShow, HelpMessage = 'Tell the script if it is running in a sub-thread to skip some regions')]
  [switch]
  $Parallel = $false,

  [Parameter(Position = 4, DontShow, HelpMessage = 'The ID of the thread')]
  [ushort]
  $WorkerID = 0,

  [Parameter(Position = 5, ValueFromRemainingArguments, HelpMessage = 'Additional parameters to be passed to the model instances')]
  [System.Collections.IEnumerable]
  $Params = @()
)

# Enable strict mode to avoid non-existent or empty properties from the API
# Set-StrictMode -Version 3.0

# In GitHub Actions, hide the progress bar to avoid pollutions to console output
if (Test-Path -Path Env:\CI) { $ProgressPreference = 'SilentlyContinue' }

# Set default parameter values for some functions
$PSDefaultParameterValues = $Global:DumplingsDefaultParameterValues = @{
  'Invoke-WebRequest:TimeoutSec'        = 30
  'Invoke-WebRequest:MaximumRetryCount' = 3
  'Invoke-WebRequest:RetryIntervalSec'  = 5
  'Invoke-RestMethod:TimeoutSec'        = 30
  'Invoke-RestMethod:MaximumRetryCount' = 3
  'Invoke-RestMethod:RetryIntervalSec'  = 5
}

# Set the PowerShell modules to be installed and imported
$DumplingsPowerShellModules = @('PowerHTML', 'powershell-yaml')

if (-not $Parallel) {
  # Set console input and output encoding to UTF-8
  $OldOutputEncoding = [System.Console]::OutputEncoding
  $OldInputEncoding = [System.Console]::InputEncoding
  [System.Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(65001)
  [System.Console]::InputEncoding = [System.Text.Encoding]::GetEncoding(65001)

  # Remove old jobs to avoid conflicts
  Get-Job | Where-Object -FilterScript { $_.Name.StartsWith('Dumplings') } | Remove-Job -Force

  # Install and import required PowerShell modules
  $InstalledModulesNames = Get-Package | Select-Object -ExpandProperty Name
  $DumplingsPowerShellModules | ForEach-Object -Process {
    if ($InstalledModulesNames -notcontains $_) {
      Write-Host -Object "`e[1mDumplings:`e[22m Installing PowerShell module ${_}"
      Install-Package -Name $_ -Source PSGallery -ProviderName PowerShellGet -Force | Out-Null
      Write-Host -Object "`e[1mDumplings:`e[22m PowerShell module ${_} is installed"
    }
  }

  # Load preference from file
  $PreferencePath = Join-Path $PSScriptRoot 'Preference.yaml'
  $Global:DumplingsPreference = $null
  if (Test-Path -Path $PreferencePath) {
    $Global:DumplingsPreference = Get-Content -Path $PreferencePath -Raw | ConvertFrom-Yaml -Ordered
  }
  if (-not $Global:DumplingsPreference) {
    $Global:DumplingsPreference = [ordered]@{}
  }
  # Load preference from parameters, with higher priority
  if ($Params -and $Params -is [System.Collections.IEnumerable]) {
    $LastKey = $null
    foreach ($Item in $Params) {
      if ($Item -cmatch '^-') {
        $LastKey = $Item -creplace '^-'
        $Global:DumplingsPreference[$LastKey] = $true
      } else {
        $Global:DumplingsPreference[$LastKey] = $Item
      }
    }
  }

  # Import libraries
  Join-Path $PSScriptRoot 'Libraries' | Get-ChildItem -Include '*.psm1' -Recurse -File | Import-Module -Force

  # Queue the tasks to load
  $TaskNames = [System.Collections.Concurrent.ConcurrentQueue[string]]($Name ?? (Get-ChildItem -Path $Path -Directory | Select-Object -ExpandProperty Name))
  $TaskNamesTotalCount = $TaskNames.Count
  Write-Log -Object "`e[1mDumplings:`e[22m $($TaskNamesTotalCount ?? 0) task(s) to load"

  # Set up temp storage for tasks
  $Global:LocalStorage = [ordered]@{}

  # Set up temp folder for tasks
  $Global:LocalCache = (New-Item -Path $PSScriptRoot -Name 'Outputs' -ItemType Directory -Force).FullName
  Get-ChildItem $LocalCache | Remove-Item -Recurse -Force

  # Switch to multi-threads mode if the number of threads is set to be greater than 1, otherwise stay in single-thread mode
  if ($ThrottleLimit -gt 1) {
    # The default number of maximum concurrent threads of ThreadJob is 5. Increase it if necessary
    if ($ThrottleLimit -gt 5) {
      # Run Start-ThreadJob once to increase the throttle limit
      Start-ThreadJob -ScriptBlock {} -ThrottleLimit $ThrottleLimit | Wait-Job | Out-Null
    }

    Write-Log -Object "`e[1mDumplings:`e[22m Starting ${ThrottleLimit} thread jobs"

    # Re-run this script in sub-threads
    $Jobs = @()
    foreach ($i in 0..($ThrottleLimit - 1)) {
      $Jobs += Start-ThreadJob -FilePath $MyInvocation.MyCommand.Definition -Name "DumplingsWok${i}" -StreamingHost $Host -ArgumentList @(
        $Name, $Path, $ThrottleLimit, $true, $i, $Params
      )
    }
  }
}

# In multi-threads mode, run tasks in sub-threads and let the main thread skip this region
# In single-thread mode, run tasks in the main thread directly
if ($Parallel -or $ThrottleLimit -eq 1) {
  # Set up parameters
  $ScriptRoot = $Parallel ? $using:PSScriptRoot : $PSScriptRoot
  if ($Parallel) {
    $TaskNames = $using:TaskNames
    $TaskNamesTotalCount = $using:TaskNamesTotalCount
    $Global:LocalStorage = $using:LocalStorage
    $Global:LocalCache = $using:LocalCache
    $Global:DumplingsPreference = $using:DumplingsPreference
  }

  # Import libraries
  Join-Path $ScriptRoot 'Libraries' | Get-ChildItem -Include '*.psm1' -Recurse -File | Import-Module

  # Import models
  Join-Path $ScriptRoot 'Models' | Get-ChildItem -Include '*.ps1' -Recurse -File | ForEach-Object -Process { . $_ }

  # Build and run tasks
  $TaskName = [string]$null
  while ($TaskNames.TryDequeue([ref]$TaskName)) {
    Write-Progress -Activity 'Dumplings' -PercentComplete (100 - $TaskNames.Count / $TaskNamesTotalCount * 100) -Status "$($TaskNamesTotalCount - $TaskNames.Count)/$($TaskNamesTotalCount) $TaskName"

    # Build task
    try {
      $TaskPath = Join-Path $Path $TaskName -Resolve
      $TaskConfig = Join-Path $TaskPath 'Config.yaml' -Resolve | Get-Item | Get-Content -Raw | ConvertFrom-Yaml -Ordered
      $Task = New-Object -TypeName $TaskConfig.Type -ArgumentList @{
        Name   = $TaskName
        Path   = $TaskPath
        Config = $TaskConfig
      }
    } catch {
      Write-Log -Object "`e[1mDumplingsWok${WorkerID}:`e[22m Failed to initialize task ${TaskName}:" -Level Error
      $_ | Out-Host
      continue
    }

    # Run task
    try {
      $Task.Invoke()
    } catch {
      Write-Log -Object "`e[1mDumplingsWok${WorkerID}:`e[22m An error occured while running the script for ${TaskName}:" -Level Error
      $_ | Out-Host
    }
  }

  Write-Log -Object "`e[1mDumplingsWok${WorkerID}:`e[22m Done" -Level Verbose

  # Clean the environment for the sub-thread
  if ($Parallel) { Get-Module | Where-Object -FilterScript { $_.Path.Contains($using:PSScriptRoot) } | Remove-Module }
}

if (-not $Parallel) {
  # In multi-threads mode, let the main thread wait for all sub-threads first
  if ($ThrottleLimit -gt 1) {
    # Wait for all threads with a maximum waiting time of 1 hour
    $Jobs | Wait-Job -Timeout 3600 | Out-Null

    # Check if some threads are still running, especially after timeout
    if (Get-Job -State Running) {
      Write-Log -Object "`e[1mDumplings:`e[22m Some threads are still running and will be stopped forcibly"
      Get-Job -State Running | Out-Host
    }
  }

  # In GitHub Actions, commit and push the changes if present
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

  # Clean and restore the environment for the main thread
  Get-Module | Where-Object -FilterScript { $_.Path.Contains($PSScriptRoot) } | Remove-Module
  Get-Job | Where-Object -FilterScript { $_.Name.StartsWith('Dumplings') } | Remove-Job -Force
  [System.Console]::OutputEncoding = $OldOutputEncoding
  [System.Console]::InputEncoding = $OldInputEncoding
  # Set-StrictMode -Off
}
