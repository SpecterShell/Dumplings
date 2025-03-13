$Object1 = Invoke-RestMethod -Uri 'https://api.yunxiu.meitu.com/api/v2/client/latest' -Method Post -Body (
  @{
    client_system  = 1
    client_version = $this.Status.Contains('New') ? '6.13.3' : $this.LastState.Version
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

# Version
$this.CurrentState.Version = $Object1.data.version.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.version.extension.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.version.updated_at.ToUniversalTime()

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.version.desc | Format-Text
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

      $ReleaseNotesUrlObject = $Object2.data.data.Where({ $_.id -eq 6 }, 'First')[0].articles.Where({ $_.title.StartsWith("V$($this.CurrentState.Version)") }, 'First')
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
