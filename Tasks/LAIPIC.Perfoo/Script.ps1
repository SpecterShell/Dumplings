$Object1 = (Invoke-RestMethod -Uri 'https://presentment-api.laihua.com/common/config?type=120').data.perfooUpdatePC | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.versionCode

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloadUrl
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.description.Replace('；', "；`n") | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
