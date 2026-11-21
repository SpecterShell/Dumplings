$Object1 = Invoke-RestMethod -Uri 'https://cad.glodon.com/update/version/info/cadpc'

# Version
$this.CurrentState.Version = $Object1.body.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.body.url | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object1.body.pageUrl | ConvertTo-Https
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('/html/body/div/p[@style="margin-top: 30px;"]/following-sibling::p[count(.|/html/body/div/p[@style="margin-top:30px;"]/preceding-sibling::p)=count(/html/body/div/p[@style="margin-top:30px;"]/preceding-sibling::p)]') | Get-TextContent | Format-Text
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
