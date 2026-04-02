$Object1 = Invoke-RestMethod -Uri 'https://www.dola.com/service/settings/v3/?device_platform=web&brand=cici&aid=582465'
# $Object1 = Invoke-RestMethod -Uri 'https://www.dola.com/service/settings/v3/?device_platform=web&brand=dola&aid=582478'

# Version
$this.CurrentState.Version = $Object1.data.settings.saman_update_address.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Object1.data.settings.saman_update_address.win_x64_url "../$($this.CurrentState.Version)/Dola_installer_$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.settings.saman_update_address.release_note
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
