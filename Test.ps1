#Requires -Version 7

<#
.SYNOPSIS
  Run tests on tasks, regardless of skipping mode and comparison status
.PARAMETER Name
  The name of the tasks to be tested. Leave blank to test all tasks
.PARAMETER AllowWrite
  Allow writing states
.PARAMETER AllowMessage
  Allow sending messages
.PARAMETER Path
  The path containing tasks
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
    HelpMessage = 'Allow writing states'
  )]
  [switch]
  $AllowWrite = $false,

  [Parameter(
    HelpMessage = 'Allow sending messages'
  )]
  [switch]
  $AllowMessage = $false,

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
    Install-Package -Name $_ -Source PSGallery -ProviderName PowerShellGet -Force
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
  $Path, $Name, $true, $true, -not $AllowWrite, -not $AllowMessage, $true
)
Join-Path $PSScriptRoot 'Modules' 'Telegram.psm1' | Import-Module -Force -ArgumentList @(
  $Env:TG_BOT_TOKEN, $Env:TG_CHAT_ID
)

# Invoke tasks
Invoke-TaskPipeline | Out-Null

# Wait for all messages to be sent
Wait-Event -SourceIdentifier 'DumplingsMessageFinished' | Out-Null

# Remove related events, event subscribers, extensions, modules and variables
Get-Event | Where-Object -FilterScript { $_.SourceIdentifier.StartsWith('Dumplings') } | Remove-Event
Get-EventSubscriber | Where-Object -FilterScript { $_.SourceIdentifier.StartsWith('Dumplings') } | Unregister-Event
Get-Module | Where-Object -FilterScript { $_.Path.Contains($PSScriptRoot) } | Remove-Module
Remove-Variable -Name DumplingsDefaultParameterValues -Scope Global
