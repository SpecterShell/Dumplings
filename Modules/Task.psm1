param (
  [Parameter(
    Mandatory,
    HelpMessage = 'The path containing tasks'
  )]
  [string]
  $Path,

  [Parameter(
    HelpMessage = 'The names of the tasks'
  )]
  [string[]]
  $Name = [string[]]@(),

  [Parameter(
    HelpMessage = 'Do not skip tasks, even if they are marked to be skipped'
  )]
  [switch]
  $NoSkip = $false,

  [Parameter(
    HelpMessage = 'Force continue even if there are no differences between states'
  )]
  [switch]
  $NoCompare = $false,

  [Parameter(
    HelpMessage = 'Do not write states'
  )]
  [switch]
  $NoWrite = $false,

  [Parameter(
    HelpMessage = 'Do not send messages'
  )]
  [switch]
  $NoMessage = $false,

  [Parameter(
    HelpMessage = 'Do not create manifests'
  )]
  [switch]
  $NoPush = $false
)

class Task {
  [ValidateNotNullOrEmpty()][string]$Name
  [ValidateNotNullOrEmpty()][string]$Path
  [System.Collections.IDictionary]$Config = [ordered]@{}
  [System.Collections.IDictionary]$LastState = [ordered]@{}
  [System.Collections.IDictionary]$CurrentState = [ordered]@{
    Installer = @()
    Locale    = @()
  }
}

$Script:Temp = [ordered]@{}
$Private:ChangeList = @()

function Compare-State {
  <#
  .SYNOPSIS
    Compare version and installers between states
  .PARAMETER LastState
    The state hashtable used as a reference for comparison
  .PARAMETER CurrentState
    The state hashtable that is compared to the reference object
  .PARAMETER NoVersion
    Do not compare versions
  #>
  param (
    [Parameter(
      HelpMessage = 'The state hashtable used as a reference for comparison'
    )]
    [System.Collections.IDictionary]
    $LastState = $Task.LastState,

    [Parameter(
      ValueFromPipeline,
      HelpMessage = 'The state hashtable that is compared to the reference object'
    )]
    [System.Collections.IDictionary]
    $CurrentState = $Task.CurrentState
  )

  if ($NoCompare) {
    Write-Host -Object 'Task: Comparison is skipped'
    return 2
  }

  if (-not $CurrentState.Version) {
    throw "Task $($Task.Name): Property Version is undefined or invalid in the current state"
  }
  if (-not $CurrentState.Installer.InstallerUrl) {
    throw "Task $($Task.Name): Property InstallerUrl is undefined or invalid in the current state"
  }

  if (-not $LastState.Version) {
    return 1
  }

  if ($LastState.Version -eq $CurrentState.Version) {
    $Diff = Compare-Object -ReferenceObject $LastState -DifferenceObject $CurrentState -Property { $_.Installer.InstallerUrl }
    if ($Diff) {
      Write-Host -Object "Task $($Task.Name): Installers changed"
      $Diff | Out-Host
      return 2
    }
  }

  if ((Compare-Version -ReferenceVersion $LastState.Version -DifferenceVersion $CurrentState.Version) -eq 1) {
    Write-Host -Object "Task $($Task.Name): Version changed: $($Task.LastState.Version) -> $($Task.CurrentState.Version)"
    return 3
  }

  return 0
}

function Write-State {
  <#
  .SYNOPSIS
    Write the state to a log file and a state file in JSON format
  .PARAMETER State
    The state hashtable to be written to the file
  #>
  param (
    [Parameter(
      ValueFromPipeline,
      HelpMessage = 'The state hashtable to be written to the file'
    )]
    [System.Collections.IDictionary]
    $State = $Task.CurrentState
  )

  if ($NoWrite) {
    Write-Host -Object 'Task: Writing feature is disabled'
  } else {
    $ChangeList += $Task.Config.Identifier

    # Writing current state to log file
    $LogPath = Join-Path $Task.Path "Log_$(Get-Date -AsUTC -Format "yyyyMMdd'T'HHmmss'Z'").json"
    Write-Host -Object "Task $($Task.Name): Writing current state to log file ${LogPath}"
    $State | ConvertTo-Json | Out-File -FilePath $LogPath

    # Writing current state to state file
    $StatePath = Join-Path $Task.Path 'State.json'
    Write-Host -Object "Task $($Task.Name): Writing current state to state file ${StatePath}"
    $State | ConvertTo-Json | Out-File -FilePath $StatePath
  }
}

function Send-Message {
  <#
  .SYNOPSIS
    Send the message to specified targets
  .PARAMETER Message
    The message content to be sent
  #>
  param (
    [Parameter(
      Mandatory, ValueFromPipeline,
      HelpMessage = 'The message content to be sent'
    )]
    $Message
  )

  if ($NoMessage) {
    Write-Host -Object 'Task: Message feature is disabled'
  } else {
    Write-Host -Object "Task $($Task.Name): Sending message"
    New-Event -SourceIdentifier 'DumplingsMessageSend' -Sender 'Task' -EventArguments $Message | Out-Null
  }
}

function Send-VersionMessage {
  <#
  .SYNOPSIS
    Generate a package information message and send
  .PARAMETER State
    The state hashtable to be parsed and sent
  #>
  param (
    [Parameter(
      ValueFromPipeline,
      HelpMessage = 'The state hashtable to be parsed and sent'
    )]
    [System.Collections.IDictionary]
    $State = $Task.CurrentState
  )

  $Message = [ordered]@{
    Entries = [ordered]@{}
  }

  # Identifier
  $Message.Title = $Task.Config.Identifier
  # Notes
  if ($Task.Config.Notes) {
    $Message.Subtitle = $Task.Config.Notes
  }
  # RealVersion / Version
  if ($State.RealVersion -or $State.Version) {
    $Message.Entries['版本'] = $State.RealVersion ?? $State.Version
  }
  # Installer
  if ($State.Installer) {
    $Message.Entries['地址'] = ($State.Installer | ForEach-Object -Process { [uri]::EscapeUriString($_.InstallerUrl) }) -join "`n"
  }
  # ReleaseTime
  if ($State.ReleaseTime) {
    if ($State.ReleaseTime -is [datetime]) {
      $Message.Entries['日期'] = $State.ReleaseTime.ToString('yyyy-MM-dd')
    } else {
      $Message.Entries['日期'] = $State.ReleaseTime
    }
  }
  # Locale
  foreach ($Entry in $State.Locale) {
    if ($Entry.Value) {
      switch ($Entry.Key) {
        'ReleaseNotes' { $Key = '说明' }
        'ReleaseNotesUrl' { $Key = '链接' }
        Default { $Key = $Entry.Key ?? '未知' }
      }
      if ($Entry.Locale) {
        $Key += "（$($Entry.Locale)）"
      }
      $Message.Entries[$Key] = $Entry.Value
    }
  }

  Send-Message -Message $Message
}

function Send-OutdatedMessage {
  <#
  .SYNOPSIS
    Generate an outdated package message and send
  .PARAMETER State
    The state hashtable to be parsed and sent
  #>
  param (
    [Parameter(
      HelpMessage = 'The state hashtable to be parsed and sent',
      Position = 0,
      ValueFromPipeline = $true
    )]
    [System.Collections.IDictionary]
    $State = $Task.CurrentState
  )

  $Message = [ordered]@{
    Title    = $Task.Config.Identifier
    Subtitle = '最低支持版本已变更'
    Entries  = [ordered]@{
      版本 = $Task.CurrentState.ForceVersion
    }
  }

  Send-Message -Message $Message
}

function New-Manifest {
  <#
  .SYNOPSIS
    Generate a new package manifest
  .PARAMETER State
    The state hashtable for generating a new package manifest
  #>
  param (
    [Parameter(
      ValueFromPipeline,
      HelpMessage = 'The state hashtable for generating new manifest'
    )]
    [System.Collections.IDictionary]
    $State = $Task.CurrentState
  )

  if ($NoPush) {
    Write-Host -Object 'Task: Manifest feature is disabled'
  } else {
    Write-Host -Object 'Task: Manifest feature has not been implemented yet'
  }
}

function Invoke-TaskPipeline {
  <#
  .SYNOPSIS
    Invoke tasks
  #>

  foreach ($Private:TaskDirectory in $TaskDirectories) {
    $Task = [Task]@{
      Name = $TaskDirectory.Name
      Path = $TaskDirectory.FullName
    }
    Write-Verbose -Message "Task: Start processing task $($Task.Name) in $($Task.Path)"

    # Load config
    $Private:ConfigPath = Join-Path $TaskDirectory 'Config.json'
    Write-Verbose -Message "Task $($Task.Name): Loading config in ${ConfigPath}"
    try {
      $Task.Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json -AsHashtable
    } catch {
      Write-Host -Object "Task $($Task.Name): Failed to load config in ${ConfigPath}" -ForegroundColor Red
      Write-Error -ErrorRecord $_ -CategoryActivity "Task $($Task.Name)"
      continue
    }

    # Skip task on demand
    if (-not $NoSkip -and $Task.Config.Skip) {
      Write-Host -Object "Task $($Task.Name): Skipped"
      continue
    }

    # Load last state
    $Private:LastStatePath = Join-Path $Task.Path 'State.json'
    if (Test-Path -Path $LastStatePath) {
      Write-Verbose -Message "Task $($Task.Name): Loading last state in ${ConfigPath}"
      try {
        $Task.LastState = Get-Content -Path $LastStatePath -Raw | ConvertFrom-Json -AsHashtable
      } catch {
        Write-Host -Object "Task $($Task.Name): Failed to load last state in ${LastStatePath}" -ForegroundColor Red
        Write-Error -ErrorRecord $_ -CategoryActivity "Task $($Task.Name)"
        continue
      }
    } else {
      Write-Host -Object "Task $($Task.Name): New task"
    }

    # Invoke script
    Write-Host -Object "Task $($Task.Name): Run!"
    try {
      & (Join-Path $Task.Path 'Script.ps1')
    } catch {
      Write-Host -Object "Task $($Task.Name): An error occured while running the script:`n${_}" -ForegroundColor Red
    }
  }

  New-Event -SourceIdentifier 'DumplingsTaskFinished' -Sender 'DumplingsTask' | Out-Null

  if ($ChangeList -gt 0) {
    Write-Host -Object "Task: The states of the following tasks have been changed:`n$($ChangeList -join "`n")"
  }
  return $ChangeList
}

# Find tasks
Write-Verbose -Message "Task: Finding tasks in ${Path}"
$TaskDirectories = @()
if ($Name) {
  $TaskDirectories += $Name |
    ForEach-Object -Process { Join-Path $Path $_ } |
    Where-Object -FilterScript {
      (Test-Path -Path @(
        Join-Path $_ 'Config.json'
        Join-Path $_ 'Script.ps1'
      )) -notcontains $false
    } |
    Get-Item
} else {
  $TaskDirectories += Get-ChildItem -Path $Path -Directory |
    Where-Object -FilterScript {
      (Test-Path -Path @(
        Join-Path $_.FullName 'Config.json'
        Join-Path $_.FullName 'Script.ps1'
      )) -notcontains $false
    }
}
Write-Host -Object "Task: $($TaskDirectories.Length ?? 0) tasks found"

Export-ModuleMember -Function Invoke-TaskPipeline
