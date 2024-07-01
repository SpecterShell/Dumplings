<#
.SYNOPSIS
  A bootstrapping script to build and run tasks, in either single-thread mode or multi-threads mode
.PARAMETER Name
  The names of the tasks to run. Leave blank to run all tasks
.PARAMETER Path
  The path to the folder containing the task files
.PARAMETER PassThru
  Pass the task objects to output
.PARAMETER ThrottleLimit
  The number of workers used to run the tasks concurrently in multi-threads mode. Set it to 1 to run in single-thread mode
.PARAMETER Params
  Additional parameters to be used by model constructors and instances. See the source code of the models for more parameters
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

#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'DumplingsDefaultParameterValues', Justification = 'This variable is shared across scripts')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'PSNativeCommandUseErrorActionPreference', Justification = 'This is a built-in variable of PowerShell')]

[CmdletBinding()]
param (
  [Parameter(Position = 0, ValueFromPipeline, HelpMessage = 'The names of the tasks to run. Leave blank to run all tasks')]
  [ArgumentCompleter({ Join-Path ($args[4].Contains('Path') ? $args[4].Path : (Join-Path $PSScriptRoot 'Tasks')) "$($args[2])*" 'Config.yaml' | Get-ChildItem -Recurse | Select-Object -ExpandProperty Directory | Select-Object -ExpandProperty Name })]
  [string[]]
  $Name,

  [Parameter(Position = 1, HelpMessage = 'The path to the folder containing the task files')]
  [string]
  $Path = (Join-Path $PSScriptRoot 'Tasks'),

  [Parameter(Position = 2, HelpMessage = 'Pass the task objects to output')]
  [switch]
  $PassThru = $false,

  [Parameter(Position = 3, HelpMessage = 'The number of workers used to run the tasks concurrently in multi-threads mode. Set it to 1 to run in single-thread mode')]
  [ValidateScript({ $_ -gt 0 }, ErrorMessage = 'The number should be positive.')]
  [ushort]
  $ThrottleLimit = 1,

  [Parameter(Position = 4, DontShow, HelpMessage = 'Tell the script if it is running in a sub-thread to skip some regions')]
  [switch]
  $Parallel = $false,

  [Parameter(Position = 5, DontShow, HelpMessage = 'The ID of the thread')]
  [ushort]
  $WorkerID = 0,

  [Parameter(Position = 6, ValueFromRemainingArguments, HelpMessage = 'Additional parameters to be passed to the model instances')]
  [System.Collections.IEnumerable]
  $Params = @()
)

# Enable strict mode to avoid non-existent or empty properties from the API
Set-StrictMode -Version 3.0

# In GitHub Actions, hide the progress bar to avoid pollutions to console output
if (Test-Path -Path Env:\CI) { $ProgressPreference = 'SilentlyContinue' }

# Force stop on error
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Set default parameter values for some functions
$PSDefaultParameterValues = $Global:DumplingsDefaultParameterValues = @{
  'Invoke-WebRequest:ConnectionTimeoutSeconds' = 30
  'Invoke-WebRequest:OperationTimeoutSeconds'  = 30
  'Invoke-WebRequest:MaximumRetryCount'        = 3
  'Invoke-WebRequest:RetryIntervalSec'         = 3
  'Invoke-WebRequest:SslProtocol'              = 'Tls12'
  'Invoke-RestMethod:ConnectionTimeoutSeconds' = 30
  'Invoke-RestMethod:OperationTimeoutSeconds'  = 30
  'Invoke-RestMethod:MaximumRetryCount'        = 3
  'Invoke-RestMethod:RetryIntervalSec'         = 3
  'Invoke-RestMethod:SslProtocol'              = 'Tls12'
}

# Set the PowerShell modules to be installed and imported
$Private:DumplingsPowerShellModules = @('PowerHTML', 'powershell-yaml')

if (-not $Parallel) {
  # Set console input and output encoding to UTF-8
  # This also affects sub threads
  $Private:OldOutputEncoding = [System.Console]::OutputEncoding
  $Private:OldInputEncoding = [System.Console]::InputEncoding
  [System.Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(65001)
  [System.Console]::InputEncoding = [System.Text.Encoding]::GetEncoding(65001)

  # Remove old jobs to avoid conflicts
  Get-Job | Where-Object -FilterScript { $_.Name.StartsWith('Dumplings') } | Remove-Job -Force

  # Install PowerShell modules
  $Private:DumplingsPowerShellModules | ForEach-Object -Process {
    if (-not (Get-Module -Name $_ -ListAvailable)) {
      Write-Host -Object "`e[1mDumplings:`e[22m Installing PowerShell module ${_}"
      Install-Module -Name $_ -Force -ErrorAction Stop | Out-Null
      Write-Host -Object "`e[1mDumplings:`e[22m PowerShell module ${_} is installed"
    }
  }

  $Global:DumplingsPreference = $null

  # Load preference from file
  $Private:DumplingsPreferencePath = Join-Path $PSScriptRoot 'Preference.yaml'
  if (Test-Path -Path $Private:DumplingsPreferencePath) {
    try {
      $Global:DumplingsPreference = Get-Content -Path $Private:DumplingsPreferencePath -Raw | ConvertFrom-Yaml -Ordered
    } catch {
      Write-Host -Object "`e[1mDumplings:`e[22m Failed to load the preference. Assigning an empty hashtable: ${_}"
    }
  }
  # ConvertFrom-Yaml will return $null if the file is empty. Assign an empty hashtable if that happened
  if (-not $Global:DumplingsPreference) {
    $Global:DumplingsPreference = [ordered]@{}
  }

  # Load preference from parameters. They have higher priority as the existing ones with the same names will be overrided
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

  # Load secret from environmental variables
  $Global:DumplingsSecret = $null
  if (Test-Path -Path Env:\DUMPLINGS_SECRET) {
    try {
      $Global:DumplingsSecret = $Env:DUMPLINGS_SECRET | ConvertFrom-Yaml -Ordered
    } catch {
      Write-Host -Object "`e[1mDumplings:`e[22m Failed to load the secret. Assigning an empty hashtable: ${_}"
    }
  }
  # ConvertFrom-Yaml will return $null if the file is empty. Assign an empty hashtable if that happened
  if (-not $Global:DumplingsSecret) {
    $Global:DumplingsSecret = [ordered]@{}
  }

  # Queue the tasks to load
  if ($Name) {
    $TaskNames = [System.Collections.Concurrent.ConcurrentQueue[string]]$Name
  } else {
    $TaskNames = [System.Collections.Concurrent.ConcurrentQueue[string]](Join-Path $Path '*' 'Config.yaml' | Get-ChildItem -Recurse | Select-Object -ExpandProperty Directory | Select-Object -ExpandProperty Name)
  }
  $TaskNamesTotalCount = $TaskNames.Count
  Write-Host -Object "`e[1mDumplings:`e[22m $($TaskNamesTotalCount ?? 0) task(s) found"

  # Set up temp storage for tasks
  $Global:DumplingsStorage = [ordered]@{}
  $Global:DumplingsSessionStorage = [ordered]@{}

  # Set up temp folder for tasks
  $Global:DumplingsCache = (New-Item -Path $Env:TEMP -Name 'Dumplings' -ItemType Directory -Force).FullName

  # Set up output folder for tasks
  $Global:DumplingsOutput = (New-Item -Path $PSScriptRoot -Name 'Outputs' -ItemType Directory -Force).FullName
  Get-ChildItem $Global:DumplingsOutput | Remove-Item -Recurse -Force

  # Switch to multi-threads mode if the number of threads is set to be greater than 1, otherwise stay in single-thread mode
  if ($ThrottleLimit -gt 1) {
    # The default number of maximum concurrent threads of ThreadJob is 5. Run Start-ThreadJob once to increase the throttle limit
    # Add the value by 5 to allow the tasks to run ThreadJob immediately instead of waiting for the sub-threads exiting
    Start-ThreadJob -ScriptBlock {} -ThrottleLimit ($ThrottleLimit + 5) | Wait-Job | Out-Null

    Write-Host -Object "`e[1mDumplings:`e[22m Starting ${ThrottleLimit} thread jobs"

    # Re-run this script in sub-threads
    $Jobs = 0..($ThrottleLimit - 1) | ForEach-Object -Process {
      Start-ThreadJob -FilePath $MyInvocation.MyCommand.Definition -Name "DumplingsWok${_}" -StreamingHost $Host -ArgumentList @($Name, $Path, $PassThru, $ThrottleLimit, $true, $_, $Params)
    }
  }
}

# In multi-threads mode, run tasks in sub-threads and let the main thread skip this region
# In single-thread mode, run tasks in the main thread directly
if ($Parallel -or $ThrottleLimit -eq 1) {
  # Set up parameters
  $Global:DumplingsRoot = $Parallel ? $using:PSScriptRoot : $PSScriptRoot
  if ($Parallel) {
    $TaskNames = $using:TaskNames
    $TaskNamesTotalCount = $using:TaskNamesTotalCount
    $Global:DumplingsStorage = $using:DumplingsStorage
    $Global:DumplingsSessionStorage = [ordered]@{}
    $Global:DumplingsCache = $using:DumplingsCache
    $Global:DumplingsOutput = $using:DumplingsOutput
    $Global:DumplingsPreference = $using:DumplingsPreference
    $Global:DumplingsSecret = $using:DumplingsSecret
  }

  # Import libraries
  Join-Path $Global:DumplingsRoot 'Libraries' | Get-ChildItem -Include '*.psm1' -Recurse -File | Import-Module

  # Import models
  Join-Path $Global:DumplingsRoot 'Models' | Get-ChildItem -Include '*.ps1' -Recurse -File | ForEach-Object -Process { . $_ }

  # Build and run tasks
  $TaskName = [string]$null
  while ($TaskNames.TryDequeue([ref]$TaskName)) {
    # Print a progress bar with a perecentage and the name of the current task
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
      Write-Log -Object "Failed to initialize task ${TaskName}:" -Identifier "DumplingsWok${WorkerID}" -Level Error
      $_ | Out-Host
      continue
    }

    # Run task
    try {
      $Task.Invoke()
    } catch {
      $Task.Log("Error: ${_}", 'Error')
      $_ | Out-Host
    }

    # Pass the task objects to output if enabled
    if ($PassThru) { Write-Output -InputObject $Task }
  }

  Write-Log -Object 'Done' -Identifier "DumplingsWok${WorkerID}" -Level Verbose

  # Clean the environment for the sub-thread
  Get-Module | Where-Object -FilterScript { $_.Path.Contains($Global:DumplingsRoot) } | Remove-Module
}

if (-not $Parallel) {
  # In multi-threads mode, let the main thread wait for all sub-threads first
  if ($ThrottleLimit -gt 1) {
    # Wait for all threads with a maximum waiting time of 50 minutes
    $Jobs | Wait-Job -Timeout 3000 | Out-Null

    # Check if some threads are still running, especially after timeout
    if ($Jobs.State -eq 'Running') {
      Write-Host -Object "`e[1mDumplings:`e[22m Some threads are still running and will be stopped forcibly"
      $Jobs | Where-Object -Property State -EQ -Value 'Running' | Out-Host
      Write-Progress -Activity 'Dumplings' -Completed -Status 'Stopped'
    } else {
      Write-Progress -Activity 'Dumplings' -Completed -Status 'Completed'
    }

    # Pass the task objects to output if enabled
    if ($PassThru) { $Jobs | Receive-Job }

    # Force remove the jobs
    $Jobs | Remove-Job -Force
  }

  # In GitHub Actions, commit and push the changes if present
  if (Test-Path -Path Env:\CI) {
    if (-not [string]::IsNullOrWhiteSpace((git ls-files --other --modified --exclude-standard $Path))) {
      Write-Host -Object "`e[1mDumplings:`e[22m Committing and pushing changes"
      git config user.name 'github-actions[bot]'
      git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
      git pull
      git add $Path
      git commit -m "${env:GITHUB_WORKFLOW}: Update states [${env:GITHUB_RUN_NUMBER}]"
      git push
    } else {
      Write-Host -Object "`e[1mDumplings:`e[22m No changes to commit"
    }
  }

  # Clean and restore the environment for the main thread
  [System.Console]::OutputEncoding = $Private:OldOutputEncoding
  [System.Console]::InputEncoding = $Private:OldInputEncoding
  Remove-Item -Path $Global:DumplingsCache -Recurse -Force
  Set-StrictMode -Off
}
