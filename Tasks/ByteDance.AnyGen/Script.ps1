$Object1 = Invoke-RestMethod -Uri 'https://www.anygen.io/service/settings/v3/?aid=835156&device_id=0&device_platform=pc&channel=website'

# Version
$this.CurrentState.Version = $Object1.data.settings.app_version_update.app_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Object1.data.settings.app_version_update.base_url "win32-x64/anygen-$($this.CurrentState.Version)-x64-setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.settings.app_version_update.desc | Format-Text
      }
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
