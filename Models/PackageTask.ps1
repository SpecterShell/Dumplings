<#
.SYNOPSIS
  A model to check updates, send messages and submit manifests for WinGet packages
.DESCRIPTION
  This model provides necessary interfaces for bootstrapping script and common methods for task scripts to automate checking updates for WinGet packages.
  Specifially it does the following:
  1. Implement a constructor and a method Invoke() to be called by the bootstrapping script:
     The constructor receives the properties, probes the script, and loads the last state ("State.yaml", if existed) which contains the information stored during previous runs.
     The Invoke() method runs the script file ("Script.ps1") in the same folder as the task config file ("Config.yaml").
  2. Implement common methods to be called by the task scripts including Logging(), Write(), Message() and Submit(), Check():
     - Log() prints the message to the console. If messaging is enabled, it will also be sent to Telegram.
     - Write() writes current state to the files "State.yaml" and "Log*.yaml", where the former file will be read in the subsequent runs.
     - Message() enables sending current state to Telegram formatted with a built-in template.
       This method then will be invoked every time the Logging() method is invoked.
     - Submit() creates and submits the package to WinGet / Scoop repository
     - Check() compares the information obtained in current run (aka current state) with that obtained in previous runs (aka last state).
       The general rule is as follows:
       1. If last state is not present, the method returns 1 and only Write() will be invoked.
       2. If last state is present and there is no difference in versions and installer URLs, the method ruturns 0 and nothing gonna happen.
       3. If last state is present and only the installer URLs are changed, the method returns 2, and Write() and Message() will be invoked.
       4. If last state is present and the version is increased, the method returns 3, and Write(), Message() and Submit() will be invoked().
       The rule for those set to check versions only is as follows:
       1. If last state is not present, the method returns 1 and only Write() will be invoked.
       2. If last state is present and there is no difference in versions, the method ruturns 0 and nothing gonna happen.
       3. If last state is present and the version is increased, the method returns 3, and Write(), Message() and Submit() will be invoked().
.PARAMETER NoSkip
  Force run the script even if the task is set not to run
.PARAMETER NoCheck
  Check() will always return 3 regardless of the difference between the states
.PARAMETER EnableWrite
  Allow Write() to write states to files
.PARAMETER EnableMessage
  Allow Message() to send states to Telegram
.PARAMETER EnableSubmit
  Allow Submit() to submit new manifests to upstream
.PARAMETER UpstreamOwner
  The owner of the upstream repository
.PARAMETER UpstreamRepo
  The name of the upstream repository
.PARAMETER UpstreamBranch
  The branch of the upstream repository
.PARAMETER OriginOwner
  The name of the origin repository
.PARAMETER OriginRepo
  The name of the origin repository
#>

enum LogLevel {
  Verbose
  Log
  Info
  Warning
  Error
}

class PackageTask {
  #region Properties
  [ValidateNotNullOrEmpty()][string]$Name
  [ValidateNotNullOrEmpty()][string]$Path
  [string]$ScriptPath
  [System.Collections.IDictionary]$Config = [ordered]@{}

  [System.Collections.IDictionary]$LastState = [ordered]@{
    Installer = @()
    Locale    = @()
  }
  [System.Collections.IDictionary]$CurrentState = [ordered]@{
    Installer = @()
    Locale    = @()
  }

  [System.Collections.Generic.List[string]]$Logs = [System.Collections.Generic.List[string]]@()
  [bool]$MessageEnabled = $false
  [int[]]$MessageID = [int[]]@()
  #endregion

  # Initialize task
  PackageTask([System.Collections.IDictionary]$Properties) {
    # Load name
    if (-not $Properties.Contains('Name')) {
      throw 'PackageTask: The property Name is undefined and should be specified'
    }
    $this.Name = $Properties.Name

    # Load path
    if (-not $Properties.Contains('Path')) {
      throw 'PackageTask: The property Path is undefined and should be specified'
    }
    if (-not (Test-Path -Path $Properties.Path)) {
      throw 'PackageTask: The property Path is not reachable'
    }
    $this.Path = $Properties.Path

    # Probe script
    $this.ScriptPath ??= Join-Path $this.Path 'Script.ps1' -Resolve

    # Load config
    if ($Properties.Contains('Config') -and $Properties.Config -is [System.Collections.IDictionary]) {
      $this.Config = $Properties.Config
    } else {
      $this.Config ??= Join-Path $this.Path 'Config.yaml' -Resolve | Get-Item | Get-Content -Raw | ConvertFrom-Yaml -Ordered
    }

    # Load last state
    $LastStatePath = Join-Path $this.Path 'State.yaml'
    if (Test-Path -Path $LastStatePath) {
      $this.LastState = Get-Content -Path $LastStatePath -Raw | ConvertFrom-Yaml -Ordered
    }

    # Log notes
    if ($this.Config.Contains('Notes')) {
      $this.Logs.Add($this.Config.Notes)
    }
  }

  # Log in specified level
  [void] Log([string]$Message, [LogLevel]$Level) {
    Write-Log -Object $Message -Identifier "PackageTask $($this.Name)" -Level $Level
    if ($Level -ne 'Verbose') {
      $this.Logs.Add($Message)
      if ($this.MessageEnabled) { $this.Message() }
    }
  }

  # Log in default level
  [void] Log([string]$Message) {
    $this.Log($Message, 'Log')
  }

  # Invoke script
  [void] Invoke() {
    if ($this.Preference.NoSkip -or -not ($this.Config.Contains('Skip') -and $this.Config.Skip)) {
      Write-Log -Object 'Run!' -Identifier "NormalTask $($this.Name)"
      & $this.ScriptPath | Out-Null
    } else {
      $this.Log('Skipped', 'Info')
    }
  }

  # Compare current state with last state
  [int] Check() {
    if (-not $Global:DumplingsPreference.Contains('NoCheck') -or -not $Global:DumplingsPreference.NoCheck) {
      if (-not $this.CurrentState.Contains('Version')) {
        throw "PackageTask $($this.Name): The property Version in the current state does not exist"
      } elseif ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
        throw "PackageTask $($this.Name): The property Version in the current state is empty or invalid"
      }

      if (-not $this.Config.Contains('CheckVersionOnly') -or -not $this.Config.CheckVersionOnly) {
        if (-not $this.CurrentState.Installer.InstallerUrl) {
          throw "PackageTask $($this.Name): The property InstallerUrl in the current state is undefined or invalid"
        }
      }

      if (-not $this.LastState.Contains('Version')) {
        return 1
      }

      switch (Compare-Version -ReferenceVersion $this.LastState.Version -DifferenceVersion $this.CurrentState.Version) {
        1 {
          $this.Log("Updated: $($this.LastState.Version) -> $($this.CurrentState.Version)", 'Info')
          return 3
        }
        0 {
          if (-not $this.Config.Contains('CheckVersionOnly') -or -not $this.Config.CheckVersionOnly) {
            if (Compare-Object -ReferenceObject $this.LastState -DifferenceObject $this.CurrentState -Property { $_.Installer.InstallerUrl }) {
              $this.Log('Installers changed', 'Info')
              return 2
            }
          }
        }
        -1 {
          $this.Log("Rollbacked: $($this.LastState.Version) -> $($this.CurrentState.Version)", 'Warning')
        }
      }

      return 0
    } else {
      $this.Log('Skip checking states', 'Info')
      return 3
    }
  }

  # Write the state to a log file and a state file in YAML format
  [void] Write() {
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      # Writing current state to log file
      $LogName = "Log_$(Get-Date -AsUTC -Format "yyyyMMdd'T'HHmmss'Z'").yaml"
      $LogPath = Join-Path $this.Path $LogName
      Write-Log -Object "Writing current state to log file ${LogPath}" -Identifier "PackageTask $($this.Name)"
      $this.CurrentState | ConvertTo-Yaml -OutFile $LogPath -Force

      # Writing current state to state file
      $StatePath = Join-Path $this.Path 'State.yaml'
      Write-Log -Object "Linking current state to the latest log file ${StatePath}" -Identifier "PackageTask $($this.Name)"
      New-Item -Path $StatePath -ItemType SymbolicLink -Value $LogName -Force
    }
  }

  # Convert current state to Markdown message
  [string] ToMarkdown() {
    $Message = [System.Text.StringBuilder]::new(2048)

    # WinGetIdentifier
    if ($this.Config.Contains('WinGetIdentifier')) { $Message.AppendLine("**$($this.Config.WinGetIdentifier)**") }

    $Message.AppendLine()

    # Version
    $Message.AppendLine("**Version:** $($this.CurrentState['Version'] | ConvertTo-MarkdownEscapedText)")
    # RealVersion
    if ($this.CurrentState.Contains('RealVersion')) { $Message.AppendLine("**RealVersion:** $($this.CurrentState['RealVersion'] | ConvertTo-MarkdownEscapedText)") }

    # Installer
    for ($i = 0; $i -lt $this.CurrentState.Installer.Count; $i++) {
      $Installer = $this.CurrentState.Installer[$i]
      $Message.AppendLine("**Installer \#${i} \($(@($Installer['InstallerLocale'], $Installer['Architecture'], $Installer['InstallerType'], $Installer['NestedInstallerType'], $Installer['Scope']) -join ', ' | ConvertTo-MarkdownEscapedText)\):**")
      $Message.AppendLine(($Installer['InstallerUrl'] | ConvertTo-MarkdownEscapedText))
    }

    # ReleaseDate
    if ($this.CurrentState.Contains('ReleaseTime')) {
      if ($this.CurrentState.ReleaseTime -is [datetime]) {
        $Message.AppendLine("**ReleaseDate:** $($this.CurrentState.ReleaseTime.ToString('yyyy-MM-dd') | ConvertTo-MarkdownEscapedText)")
      } else {
        $Message.AppendLine("**ReleaseDate:** $($this.CurrentState.ReleaseTime | ConvertTo-MarkdownEscapedText)")
      }
    }

    # Locale
    foreach ($Entry in $this.CurrentState.Locale) {
      if ($Entry.Contains('Key') -and $Entry.Key -in @('ReleaseNotes', 'ReleaseNotesUrl')) {
        $Message.AppendLine("**$($Entry['Key'] | ConvertTo-MarkdownEscapedText) \($($Entry['Locale'] | ConvertTo-MarkdownEscapedText)\):**")
        $Message.AppendLine(($Entry['Value'] | ConvertTo-MarkdownEscapedText))
      }
    }

    # Log
    if ($this.Logs.Count -gt 0) {
      $Message.AppendLine('**Log:**')
      foreach ($Log in $this.Logs) {
        $Message.AppendLine(($Log | ConvertTo-MarkdownEscapedText))
      }
    }

    # Standard Markdown use two line endings as newline
    return $Message.ToString().Trim().ReplaceLineEndings("`n`n")
  }

  # Convert current state to Markdown message in Telegram standard
  [string] ToTelegramMarkdown() {
    $Message = [System.Text.StringBuilder]::new(2048)

    # WinGetIdentifier
    if ($this.Config.Contains('WinGetIdentifier')) { $Message.AppendLine("*$($this.Config.WinGetIdentifier | ConvertTo-TelegramEscapedText)*") }

    $Message.AppendLine()

    # Version
    $Message.AppendLine("*Version:* $($this.CurrentState['Version'] | ConvertTo-TelegramEscapedText)")
    # RealVersion
    if ($this.CurrentState.Contains('RealVersion')) { $Message.AppendLine("*RealVersion:* $($this.CurrentState['RealVersion'] | ConvertTo-TelegramEscapedText)") }

    # Installer
    for ($i = 0; $i -lt $this.CurrentState.Installer.Count; $i++) {
      $Installer = $this.CurrentState.Installer[$i]
      $Message.AppendLine("*Installer \#${i} \($(@($Installer['InstallerLocale'], $Installer['Architecture'], $Installer['InstallerType'], $Installer['NestedInstallerType'], $Installer['Scope']) -join ', ' | ConvertTo-TelegramEscapedText)\):*")
      $Message.AppendLine(($Installer['InstallerUrl'] | ConvertTo-TelegramEscapedText))
    }

    # ReleaseTime
    if ($this.CurrentState.Contains('ReleaseTime')) {
      if ($this.CurrentState.ReleaseTime -is [datetime]) {
        $Message.AppendLine("*ReleaseDate:* $($this.CurrentState.ReleaseTime.ToString('yyyy-MM-dd') | ConvertTo-TelegramEscapedText)")
      } else {
        $Message.AppendLine("*ReleaseDate:* $($this.CurrentState.ReleaseTime | ConvertTo-TelegramEscapedText)")
      }
    }

    # Locale
    foreach ($Entry in $this.CurrentState.Locale) {
      if ($Entry.Contains('Key') -and $Entry.Key -in @('ReleaseNotes', 'ReleaseNotesUrl')) {
        $Message.AppendLine("*$($Entry['Key'] | ConvertTo-TelegramEscapedText) \($($Entry['Locale'] | ConvertTo-TelegramEscapedText)\)*")
        $Message.AppendLine(($Entry['Value'] | ConvertTo-TelegramEscapedText))
      }
    }

    $Message.AppendLine()

    # Log
    if ($this.Logs.Count -gt 0) {
      $Message.AppendLine('*Log:*')
      foreach ($Log in $this.Logs) {
        $Message.AppendLine(($Log | ConvertTo-TelegramEscapedText))
      }
    }

    return $Message.ToString().Trim()
  }

  # Print current state to console
  [void] Print() {
    $this.ToMarkdown() | Show-Markdown | Write-Log
  }

  # Send default message to Telegram
  [void] Message() {
    # Enable pushing new logs to Telegram once this method is called
    if (-not $this.MessageEnabled) { $this.MessageEnabled = $true }
    if ($Global:DumplingsPreference.Contains('EnableMessage') -and $Global:DumplingsPreference.EnableMessage) {
      try {
        $this.MessageID = Send-TelegramMessage -Message $this.ToTelegramMarkdown() -AsMarkdown -MessageID $this.MessageID
      } catch {
        Write-Log -Object "Failed to send default message: ${_}" -Identifier "PackageTask $($this.Name)" -Level Error
        $this.Logs.Add($_.ToString())
      }
    }
  }

  # Send custom message to Telegram
  [void] Message([string]$Message) {
    if ($Global:DumplingsPreference.Contains('EnableMessage') -and $Global:DumplingsPreference.EnableMessage) {
      try {
        Send-TelegramMessage -Message $Message | Out-Null
      } catch {
        Write-Log -Object "Failed to send custom message: ${_}" -Identifier "PackageTask $($this.Name)" -Level Error
        $this.Logs.Add($_.ToString())
      }
    }
  }

  # Generate manifests and upload them to the origin repository, and then create pull request in the upstream repository
  [void] Submit() {
    if ($Global:DumplingsPreference.Contains('EnableSubmit') -and $Global:DumplingsPreference.EnableSubmit) {
      #region WinGet
      if ($this.Config.Contains('WinGetIdentifier')) {
        $this.Log('Submitting WinGet manifests', 'Info')
        Join-Path $Global:DumplingsRoot 'Modules' 'WinGet.psm1' | Import-Module
        New-WinGetManifest -Task $this
      }
      #endregion
    }
  }
}
