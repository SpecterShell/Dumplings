$Object1 = Invoke-WebRequest -Uri 'https://xiaoyi.huawei.com/work/' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//script[@id="common"]').InnerHtml | ConvertFrom-Json
$Object3 = Invoke-RestMethod -Uri "$($Object2.config.xyWork.xyWorkClientDownloadJsonUrl)?t=$([DateTime]::UtcNow.Ticks)"

# Version
$this.CurrentState.Version = $Object3.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object3.win.url | Split-Uri -LeftPart Path
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesObject = $Object3.updateLog.Where({ $_.version -eq $this.CurrentState.Version }, 'First')
      if ($ReleaseNotesObject) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesObject[0].publishedAt.ToUniversalTime()

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject[0].notesList | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
