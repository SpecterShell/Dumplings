$Object1 = Invoke-RestMethod -Uri 'https://downloads.noderr.xyz/windows/latest/version.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = Join-Uri "https://downloads.noderr.xyz/windows/$($this.CurrentState.Version)/" $Object1.files.installer.name
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate.ToUniversalTime()

      # # ReleaseNotes (en-US)
      # $this.CurrentState.Locale += [ordered]@{
      #   Locale = 'en-US'
      #   Key    = 'ReleaseNotes'
      #   Value  = $Object1.changelog | Format-Text
      # }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}

