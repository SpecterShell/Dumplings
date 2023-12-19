$Object1 = Invoke-RestMethod -Uri 'https://close.mtlab.meitu.com/api/v1/client/latest?system=1'

# Version
$this.CurrentState.Version = $Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = ($Object1.data.extension | ConvertFrom-Json).url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.data.updated_at

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.desc | ConvertFrom-Html | Get-TextContent | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri 'https://api-compos.yunxiu.meitu.com/api/v1/client/article_category?with_article=1'

    try {
      $Prefix = 'https://yunxiu.meitu.com/document/daily-record'
      $ReleaseNotesUrlObject = $Object2.data.data.Where({ $_.id -eq 2 }).articles.Where({ $_.title.StartsWith("V${Version} ") })
      if ($ReleaseNotesUrlObject) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Prefix + '?id=' + $ReleaseNotesUrlObject.id
        }
      } else {
        $this.Logging("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Prefix
        }
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
