$Object1 = Invoke-RestMethod -Uri 'https://cad.glodon.com/update/version/info/cadpc'

# Version
$this.CurrentState.Version = $Object1.body.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl           = $Object1.body.url
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "CAD快速看图v$($this.CurrentState.Version)"
      ProductCode = '{DDD659B5-6B07-4F5A-A0D3-9E8D3147E165}_is1'
    }
  )
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = $Object1.body.pageUrl
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('/html/body/div/p[@style="margin-top: 30px;"]/following-sibling::p[count(.|/html/body/div/p[@style="margin-top:30px;"]/preceding-sibling::p)=count(/html/body/div/p[@style="margin-top:30px;"]/preceding-sibling::p)]').InnerText | Format-Text
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
