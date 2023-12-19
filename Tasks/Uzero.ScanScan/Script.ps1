$Object = Invoke-RestMethod -Uri 'https://cdn.desktop.baimiaoapp.com/updater/update.json'

# Version
$this.CurrentState.Version = [regex]::Match($Object.name, 'v(.+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object.platforms.'windows-x86_64'.url
  NestedInstallerFiles = @(
    @{
      RelativeFilePath = "白描桌面版_$($this.CurrentState.Version)_x64_zh-CN.msi"
    }
  )
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object.pub_date.ToUniversalTime()

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.notes | Format-Text
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
