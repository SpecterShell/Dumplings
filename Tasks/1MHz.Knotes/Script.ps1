$Prefix = 'https://knotes2-release-cn.s3.amazonaws.com/win/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-WebRequest -Uri 'https://help.knotesapp.com/changelog-posts/' | ConvertFrom-Html
    $Object3 = Invoke-WebRequest -Uri 'https://help.knotesapp.cn/changelog-posts/' -SkipCertificateCheck | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object2.SelectSingleNode("/html/body/div[2]/div/article[contains(./div[1]/h2, '$($this.CurrentState.Version)')]")
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

      $ReleaseNotesCNNode = $Object3.SelectSingleNode("/html/body/div[2]/div/article[contains(./div[1]/h2, '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesCNNode) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesCNNode.SelectNodes('./div[2]//*[self::span or self::li]') |
            ForEach-Object -Process { ($_.Name -eq 'li' ? '- ' : '') + $_.InnerText } |
            Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
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
