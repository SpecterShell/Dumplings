$Object = Invoke-RestMethod -Uri 'http://fm.dl.126.net/mailmaster/update2/update_config.json'

# Version
$this.CurrentState.Version = $Object.full[0].ver

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.full[0].url
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.full[0].introduction | Split-LineEndings | Select-Object -Skip 1 | Format-Text
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
