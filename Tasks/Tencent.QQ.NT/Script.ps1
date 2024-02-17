$Object1 = Invoke-RestMethod -Uri 'https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsDownloadUrl.js' | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.ntDownloadUrl.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl = $Object1.ntDownloadX64Url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '([\d\.]+)_x64\.exe').Groups[1].Value

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.ntPublishTime | Get-Date -Format 'yyyy-MM-dd'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      # Only parse version for major updates
      if (-not $this.LastState.Contains('Version') -or ($this.CurrentState.Version.Split('.')[0..2] -join '.') -ne ($this.LastState.Version.Split('.')[0..2] -join '.')) {
        $Object2 = Invoke-RestMethod -Uri 'https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/windowsQQVersionList.js' | Get-EmbeddedJson -StartsFrom 'var params= ' | ConvertFrom-Json

        $ReleaseNotesObject = $Object2.ntLogs.Where({ $_.version.EndsWith($Object1.ntVersion) }, 'First')
        if ($ReleaseNotesObject) {
          # ReleaseNotes (zh-CN)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'zh-CN'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesObject[0].features.text | Format-Text
          }
        } else {
          $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
