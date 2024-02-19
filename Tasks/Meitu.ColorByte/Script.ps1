$Object1 = Invoke-RestMethod -Uri 'https://close.mtlab.meitu.com/api/v1/client/latest?system=1'

# Version
$this.CurrentState.Version = $Object1.data.version

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

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Prefix = 'https://yunxiu.meitu.com/document/daily-record'

      $Object2 = Invoke-RestMethod -Uri 'https://api-compos.yunxiu.meitu.com/api/v1/client/article_category?with_article=1'

      $ReleaseNotesUrlObject = $Object2.data.data.Where({ $_.id -eq 2 }, 'First')[0].articles.Where({ $_.title.StartsWith("V$($this.CurrentState.Version) ") }, 'First')
      if ($ReleaseNotesUrlObject) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Prefix + '?id=' + $ReleaseNotesUrlObject[0].id
        }
      } else {
        $this.Log("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Prefix
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
