$Object1 = Invoke-RestMethod -Uri 'https://api.trae.ai/icube/api/v1/native/version/trae/latest'
# $Object1 = Invoke-RestMethod -Uri 'https://api.marscode.cn/icube/api/v1/native/version/trae/latest'

# Version
$this.CurrentState.Version = $Object1.data.manifest.win32.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.manifest.win32.download.Where({ $_.region -eq 'va' }, 'First')[0].x64
}
# $this.CurrentState.Installer += [ordered]@{
#   InstallerUrl = $Object1.data.manifest.win32.download.Where({ $_.region -eq 'sg' }, 'First')[0].x64
# }
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object1.data.manifest.win32.download.Where({ $_.region -eq 'cn' }, 'First')[0].x64
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.manifest.win32.extra.uploadDate | ConvertFrom-UnixTimeMilliseconds
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
