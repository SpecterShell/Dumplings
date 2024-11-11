$Object1 = (Invoke-RestMethod -Uri 'https://presentment-api.laihua.com/common/config?type=120').data.perfooUpdatePC | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.versionCode -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.description.Replace('；', "；`n") | Format-Text
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
