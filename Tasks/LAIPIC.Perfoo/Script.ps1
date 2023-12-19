$Object = (Invoke-RestMethod -Uri 'https://presentment-api.laihua.com/common/config?type=120').data.perfooUpdatePC | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object.versionCode

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.downloadUrl
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.description.Replace('；', "；`n") | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
