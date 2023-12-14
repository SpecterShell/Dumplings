enum LogLevel {
  Verbose
  Log
  Info
  Warning
  Error
}

class WinGetTask {
  [ValidateNotNullOrEmpty()][string]$Name

  [ValidateNotNullOrEmpty()][string]$Path
  [string]$ConfigPath
  [string]$ScriptPath

  [System.Collections.IDictionary]$Config = [ordered]@{}
  [System.Collections.IDictionary]$Preference = [ordered]@{}
  [string[]]$Log = [string[]]@()

  [System.Collections.IDictionary]$LastState = [ordered]@{}
  [System.Collections.IDictionary]$CurrentState = [ordered]@{
    Installer = @()
    Locale    = @()
  }

  WinGetTask([System.Collections.IDictionary]$Properties) {
    $this.Init($Properties)
  }

  WinGetTask([string]$Name, [string]$Path) {
    $this.Init(@{ Name = $Name; Path = $Path })
  }

  [void] Init([System.Collections.IDictionary]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }

    # Load config
    $this.ConfigPath ??= Join-Path $this.Path 'Config.yaml' -Resolve
    $this.Config ??= Get-Content -Path $this.ConfigPath -Raw | ConvertFrom-Yaml

    # Test script
    $this.ScriptPath ??= Join-Path $this.Path 'Script.ps1' -Resolve

    # Load last state
    $LastStatePath ??= Join-Path $this.Path 'State.yaml'
    if (Test-Path -Path $LastStatePath) {
      $this.LastState = Get-Content -Path $LastStatePath -Raw | ConvertFrom-Yaml
    } else {
      $this.Logging('New task')
    }

    # Log notes
    if ($this.Config.Notes) {
      $this.Log += $this.Config.Notes
    }
  }

  [void] Logging([string]$Message) {
    Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m ${Message}"
    $this.Log += $Message
  }

  [void] Logging([string]$Message, [LogLevel]$Level) {
    Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m ${Message}" -Level $Level
    $this.Log += $Message
  }

  [void] Invoke() {
    if ($this.Preference.NoSkip -or -not $this.Config.Skip) {
      try {
        Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m Run!"
        & $this.ScriptPath | Out-Null
      } catch {
        $this.Logging('An error occured while running the script:', 'Error')
        $_ | Out-Host
      }
    } else {
      $this.Logging('Skipped', 'Info')
    }
  }

  # Compare version and installers between states
  [int] Check() {
    if (-not $this.Preference.NoCheck) {
      if (-not $this.CurrentState.Version) {
        throw "WinGetTask $($this.Name): The property Version in the current state is undefined or invalid"
      }

      if (-not $this.Config.CheckVersionOnly) {
        if (-not $this.CurrentState.Installer.InstallerUrl) {
          throw "WinGetTask $($this.Name): The property InstallerUrl in the current state is undefined or invalid"
        }
      }

      if (-not $this.LastState.Version) {
        return 1
      }

      switch (Compare-Version -ReferenceVersion $this.LastState.Version -DifferenceVersion $this.CurrentState.Version) {
        1 {
          $this.Logging("Updated: $($this.LastState.Version) -> $($this.CurrentState.Version)", 'Info')
          return 3
        }
        0 {
          if (-not $this.Config.CheckVersionOnly) {
            if (Compare-Object -ReferenceObject $this.LastState -DifferenceObject $this.CurrentState -Property { $_.Installer.InstallerUrl }) {
              $this.Logging('Installers changed', 'Info')
              return 2
            }
          }
        }
        -1 {
          $this.Logging("Rollbacked: $($this.LastState.Version) -> $($this.CurrentState.Version)", 'Warning')
        }
      }

      return 0
    } else {
      $this.Logging('Skip checking states', 'Info')
      return 2
    }
  }

  # Write the state to a log file and a state file in YAML format
  [void] Write() {
    if (-not $this.Preference.NoWrite) {
      # Writing current state to log file
      $LogPath = Join-Path $this.Path "Log_$(Get-Date -AsUTC -Format "yyyyMMdd'T'HHmmss'Z'").yaml"
      Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m Writing current state to log file ${LogPath}"
      $this.CurrentState | ConvertTo-Yaml -OutFile $LogPath -Force

      # Writing current state to state file
      $StatePath = Join-Path $this.Path 'State.yaml'
      Write-Log -Object "`e[1mWinGetTask $($this.Name):`e[22m Writing current state to state file ${StatePath}"
      Copy-Item -Path $LogPath -Destination $StatePath -Force
    } else {
      $this.Logging('Skip writing states to manifests', 'Info')
    }
  }

  [string] ToMarkdown() {
    $Message = [System.Text.StringBuilder]::new(2048)

    # Identifier
    $Message.Append("*$($this.Config.Identifier)*`n")

    # RealVersion / Version
    if ($this.CurrentState.RealVersion -or $this.CurrentState.Version) {
      $Message.Append("`n*版本:* $($this.CurrentState.RealVersion ?? $this.CurrentState.Version)")
    }

    # Installer
    if ($this.CurrentState.Installer) {
      $Message.Append("`n*地址:*`n`n$($this.CurrentState.Installer.InstallerUrl -join "`n")")
    }
    # ReleaseTime
    if ($this.CurrentState.ReleaseTime) {
      if ($this.CurrentState.ReleaseTime -is [datetime]) {
        $Message.Append("`n*日期:* $($this.CurrentState.ReleaseTime.ToString('yyyy-MM-dd'))")
      } else {
        $Message.Append("`n*日期:* $($this.CurrentState.ReleaseTime)")
      }
    }
    # Locale
    foreach ($Entry in $this.CurrentState.Locale) {
      if ($Entry.Value) {
        $Key = $null
        switch ($Entry.Key) {
          'ReleaseNotes' { $Key = '说明' }
          'ReleaseNotesUrl' { $Key = '链接' }
          Default { $Key = $Entry.Key ?? '未知' }
        }
        if ($Entry.Locale) {
          $Key += " ($($Entry.Locale))"
        }
        $Message.Append("`n*${Key}:* `n$($Entry.Value)")
      }
    }

    return $Message.ToString().Trim().ReplaceLineEndings("`n`n")
  }

  [string] ToTelegramMarkdown() {
    $Message = [System.Text.StringBuilder]::new(2048)

    # Identifier
    $Message.Append("*$($this.Config.Identifier | ConvertTo-TelegramEscapedText)*`n")

    # RealVersion / Version
    if ($this.CurrentState.RealVersion -or $this.CurrentState.Version) {
      $Message.Append("`n*版本:* ``$(($this.CurrentState.RealVersion ?? $this.CurrentState.Version) | ConvertTo-TelegramEscapedCode)``")
    }

    # Installer
    if ($this.CurrentState.Installer) {
      $Delimiter = '`' + "`n" + '`'
      $Message.Append("`n*地址:*`n``$($this.CurrentState.Installer.InstallerUrl -join $Delimiter | ConvertTo-TelegramEscapedCode)``")
    }
    # ReleaseTime
    if ($this.CurrentState.ReleaseTime) {
      if ($this.CurrentState.ReleaseTime -is [datetime]) {
        $Message.Append("`n*日期:* ``$($this.CurrentState.ReleaseTime.ToString('yyyy-MM-dd') | ConvertTo-TelegramEscapedCode)``")
      } else {
        $Message.Append("`n*日期:* ``$($this.CurrentState.ReleaseTime | ConvertTo-TelegramEscapedCode)``")
      }
    }
    # Locale
    foreach ($Entry in $this.CurrentState.Locale) {
      if ($Entry.Value) {
        $Key = $null
        switch ($Entry.Key) {
          'ReleaseNotes' { $Key = '说明' }
          'ReleaseNotesUrl' { $Key = '链接' }
          Default { $Key = $Entry.Key ?? '未知' }
        }
        if ($Entry.Locale) {
          $Key += " ($($Entry.Locale))"
        }
        $Message.Append("`n*$($Key | ConvertTo-TelegramEscapedText):* `n$($Entry.Value | ConvertTo-TelegramEscapedText)")
      }
    }

    return $Message.ToString().Trim()
  }

  # Send default message to Telegram
  [void] Message() {
    $this.ToMarkdown() | Show-Markdown | Write-Log
    if (-not $this.Preference.NoMessage) {
      $Message = $this.ToTelegramMarkdown()
      New-Event -SourceIdentifier 'DumplingsMessageSend' -Sender 'Task' -EventArguments $Message | Out-Null
    } else {
      $this.Logging('Skip sending messages', 'Info')
    }
  }

  # Send specified message to Telegram
  [void] Message([string]$Message) {
    $Message | Write-Log
    if (-not $this.Preference.NoMessage) {
      $Message = $Message | ConvertTo-TelegramEscapedText
      New-Event -SourceIdentifier 'DumplingsMessageSend' -Sender 'Task' -EventArguments $Message | Out-Null
    } else {
      $this.Logging('Skip sending messages', 'Info')
    }
  }

  [void] Submit() {
    if (-not $this.Preference.NoSubmit) {
      $this.Logging('Not implemented yet')
    } else {
      $this.Logging('Skip submitting manifests', 'Info')
    }
  }
}
