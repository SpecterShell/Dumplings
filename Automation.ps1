#Requires -Version 7

<#
.SYNOPSIS
  Run automation on tasks
.PARAMETER Name
  The name of the tasks to be automated. Leave blank to automate all tasks
.PARAMETER Path
  The path containing tasks
.EXAMPLE
  .\Automation.ps1
  Run automation on all tasks
.EXAMPLE
  .\Automation.ps1 -Name '115.115'
  Run automation on task "115.115"
#>
param (
  [Parameter(
    HelpMessage = 'The name of the tasks to be automated. Leave blank to automate all tasks',
    Position = 0,
    ValueFromPipeline = $true
  )]
  [ArgumentCompleter(
    {
      Join-Path ($args[4].Path ?? (Join-Path -Path $PSScriptRoot -ChildPath 'Tasks')) "$($args[2])*" |
        Get-ChildItem -Directory |
        Where-Object -FilterScript {
          (Test-Path -Path @(
            Join-Path $_.FullName 'Config.json'
            Join-Path $_.FullName 'Script.ps1'
          )) -notcontains $false
        } |
        Select-Object -ExpandProperty 'Name'
    }
  )]
  [string[]]
  $Name = [string[]]@(),

  [Parameter(
    HelpMessage = 'The path containing tasks'
  )]
  [string]
  $Path = (Join-Path $PSScriptRoot 'Tasks')
)

# Hide progress bar for Invoke-WebRequest
if ([console]::IsOutputRedirected -or $Env:CI) {
  $ProgressPreference = 'SilentlyContinue'
}

# Set default parameter values for extensions and modules
$Global:DumplingsDefaultParameterValues = @{
  'Invoke-WebRequest:TimeoutSec'        = 512
  'Invoke-WebRequest:MaximumRetryCount' = 4
  'Invoke-WebRequest:RetryIntervalSec'  = 16
  'Invoke-RestMethod:TimeoutSec'        = 512
  'Invoke-RestMethod:MaximumRetryCount' = 4
  'Invoke-RestMethod:RetryIntervalSec'  = 16
}

# Install and import required PowerShell modules
@('PowerHTML', 'powershell-yaml') | ForEach-Object -Process {
  if (Get-Package | Where-Object -Property 'Name' -EQ -Value $_) {
    Write-Verbose -Message "Dumplings: PowerShell module ${_} has already been installed"
  } else {
    Write-Host -Object "Dumplings: Installing PowerShell module ${_}"
    Install-Package -Name $_ -Source PSGallery -ProviderName PowerShellGet
    Write-Host -Object "Dumplings: PowerShell module ${_} installed"
  }
}

# Remove related events and event subscribers in case of conflicts
Get-EventSubscriber | Where-Object -FilterScript { $_.SourceIdentifier.StartsWith('Dumplings') } | Unregister-Event

# Import extensions
Write-Verbose -Message 'Dumplings: Loading extensions'
Join-Path $PSScriptRoot 'Extensions' | Get-ChildItem -Include '*.psm1' -Recurse -File | Import-Module -Force

# Import modules
Write-Verbose -Message 'Dumplings: Loading modules'
Join-Path $PSScriptRoot 'Modules' 'Task.psm1' | Import-Module -Force -ArgumentList @(
  $Path, $Name, $false, $false, $false, $false, $false
)
Join-Path $PSScriptRoot 'Modules' 'Telegram.psm1' | Import-Module -Force -ArgumentList @(
  $Env:TG_BOT_TOKEN, $Env:TG_CHAT_ID
)

# Invoke tasks
if (Invoke-TaskPipeline) {
  Write-Host -Object 'Dumplings: Committing changes'
  if ($Env:CI) {
    git config user.name 'github-actions[bot]'
    git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
  }
  git pull
  git add $Path
  if ($Env:CI) {
    git commit -m "Automation: Update states [$env:GITHUB_RUN_NUMBER]"
  } else {
    git commit -m 'Automation: Update states [Manual]'
  }
  git push
}

# Wait for all messages to be sent
Wait-Event -SourceIdentifier 'DumplingsMessageFinished' | Out-Null

# Remove related events, event subscribers, extensions, modules and variables
Get-Event | Where-Object -FilterScript { $_.SourceIdentifier.StartsWith('Dumplings') } | Remove-Event
Get-EventSubscriber | Where-Object -FilterScript { $_.SourceIdentifier.StartsWith('Dumplings') } | Unregister-Event
Get-Module | Where-Object -FilterScript { $_.Path.Contains($PSScriptRoot) } | Remove-Module
Remove-Variable -Name DumplingsDefaultParameterValues -Scope Global
