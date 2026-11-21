$Object1 = Invoke-RestMethod -Uri 'https://close.mtlab.meitu.com/api/v1/client/latest' -Body @{
  version = $this.Status.Contains('New') ? '5.9.2' : $this.LastState.Version
  system  = '1'
}

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = ($Object1.data.extension | ConvertFrom-Json).url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.updated_at.ToUniversalTime()

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.desc | ConvertFrom-Html | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = 'https://yunxiu.meitu.com/document/daily-record'
      }

      $Object2 = Invoke-RestMethod -Uri 'https://api-compos.yunxiu.meitu.com/api/v1/client/article_category?with_article=1'

      $ReleaseNotesUrlObject = $Object2.data.data.Where({ $_.id -eq 2 }, 'First')[0].articles.Where({ $_.title.StartsWith("V$($this.CurrentState.Version)") }, 'First')
      if ($ReleaseNotesUrlObject) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl + '?id=' + $ReleaseNotesUrlObject[0].id
        }
      } else {
        $this.Log("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
