$Object1 = Invoke-RestMethod -Uri 'https://cdn.desktop.baimiaoapp.com/updater/update.json'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.name, 'v(.+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object1.platforms.'windows-x86_64'.url
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "白描桌面版_$($this.CurrentState.Version)_x64_zh-CN.msi"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pub_date.ToUniversalTime()

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.notes | Format-Text
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
