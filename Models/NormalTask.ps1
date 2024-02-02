<#
.SYNOPSIS
  A model with the minimum logic necessary to run a script
.DESCRIPTION
  This model provides necessary interfaces for bootstrapping script and common method for task scripts.
  Generally it does the following:
  1. Implement a constructor and a method Invoke() to be called by the bootstrapping script:
     The constructor receives the properties and probes the script.
     The Invoke() method runs the script file ("Script.ps1") in the same folder as the task config file ("Config.yaml").
  2. Implement common method to be called by the task scripts including Logging():
     - Logging() prints the message to the console. If messaging is enabled, it will also be sent to Telegram.
.PARAMETER NoSkip
  Force run the script even if the task is set not to run
#>

enum LogLevel {
  Verbose
  Log
  Info
  Warning
  Error
}

class NormalTask {
  #region Properties
  [ValidateNotNullOrEmpty()][string]$Name

  [ValidateNotNullOrEmpty()][string]$Path
  [string]$ScriptPath

  [System.Collections.IDictionary]$Config = [ordered]@{}
  [System.Collections.IDictionary]$Preference = [ordered]@{}
  #endregion

  NormalTask([System.Collections.IDictionary]$Properties) {
    # Load name
    if (-not $Properties.Contains('Name')) {
      throw 'WinGetTask: The property Name is undefined and should be specified'
    }
    $this.Name = $Properties.Name

    # Load path
    if (-not $Properties.Contains('Path')) {
      throw 'WinGetTask: The property Path is undefined and should be specified'
    }
    if (-not (Test-Path -Path $Properties.Path)) {
      throw 'WinGetTask: The property Path is not reachable'
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

    # Load preference
    if ($Properties.Contains('Preference') -and $Properties.Preference -is [System.Collections.IEnumerable]) {
      $LastKey = $null
      foreach ($Item in $Properties.Preference) {
        if ($Item -cmatch '^-') {
          $LastKey = $Item -creplace '^-'
          $this.Preference[$LastKey] = $true
        } else {
          $this.Preference[$LastKey] = $Item
        }
      }
    }
  }

  # Log with template, without specifying log level
  [void] Logging([string]$Message) {
    Write-Log -Object "`e[1mNormalTask $($this.Name):`e[22m ${Message}"
  }

  # Log with template, specifying log level
  [void] Logging([string]$Message, [LogLevel]$Level) {
    Write-Log -Object "`e[1mNormalTask $($this.Name):`e[22m ${Message}" -Level $Level
  }

  # Invoke script
  [void] Invoke() {
    if ($this.Preference.NoSkip -or -not $this.Config.Skip) {
      try {
        Write-Log -Object "`e[1mNormalTask $($this.Name):`e[22m Run!"
        & $this.ScriptPath | Out-Null
      } catch {
        $this.Logging("An error occured while running the script: ${_}", 'Error')
        $_ | Out-Host
      }
    } else {
      $this.Logging('Skipped', 'Info')
    }
  }
}
