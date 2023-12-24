enum LogLevel {
  Verbose
  Log
  Info
  Warning
  Error
}

class NormalTask {
  [ValidateNotNullOrEmpty()][string]$Name

  [ValidateNotNullOrEmpty()][string]$Path
  [string]$ConfigPath
  [string]$ScriptPath

  [System.Collections.IDictionary]$Config = [ordered]@{}
  [System.Collections.IDictionary]$Preference = [ordered]@{}

  NormalTask([System.Collections.IDictionary]$Properties) {
    $this.Init($Properties)
  }

  NormalTask([string]$Name, [string]$Path) {
    $this.Init(@{ Name = $Name; Path = $Path })
  }

  # Initialize tasks
  [void] Init([System.Collections.IDictionary]$Properties) {
    foreach ($Property in $Properties.Keys) {
      $this.$Property = $Properties.$Property
    }

    # Load config
    $this.ConfigPath ??= Join-Path $this.Path 'Config.yaml' -Resolve
    $this.Config ??= Get-Content -Path $this.ConfigPath -Raw | ConvertFrom-Yaml -Ordered

    # Load script
    $this.ScriptPath ??= Join-Path $this.Path 'Script.ps1' -Resolve
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
