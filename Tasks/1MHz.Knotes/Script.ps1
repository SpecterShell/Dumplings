$Prefix = 'https://knotes2-release-cn.s3.amazonaws.com/win/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://help.knotesapp.com/changelog-posts/' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//article[contains(@class, 'uk-article') and contains(./div[1]/h2, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div[2]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      $Object3 = Invoke-WebRequest -Uri 'https://help.knotesapp.cn/changelog-posts/' -SkipCertificateCheck | ConvertFrom-Html

      $ReleaseNotesCNNode = $Object3.SelectSingleNode("//article[contains(@class, 'uk-article') and contains(./div[1]/h2, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesCNNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNode.SelectNodes('./div[2]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
