$Object1 = Invoke-RestMethod -Uri 'https://www.doubao.com/service/settings/v3/?device_platform=web&brand=doubao&aid=582465'

# Version
$this.CurrentState.Version = $Object1.data.settings.saman_update_address.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.data.settings.saman_update_address.win_x64_url
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.settings.saman_update_address.release_note
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
