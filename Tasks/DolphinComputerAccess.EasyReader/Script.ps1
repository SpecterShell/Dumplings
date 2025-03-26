$Object1 = Invoke-RestMethod -Uri 'https://yourdolphin.com/api/v1/products/8/versions/with-downloads'

# Version
$this.CurrentState.Version = "$($Object1[0].major).0.$($Object1[0].minor).$($Object1[0].build)"
# 1105
$ShortVersion = '{0}{1:d2}' -f $Object1[0].major, [int]($Object1[0].minor)

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://exdownloads.yourdolphin.com/software/EasyReader/${ShortVersion}/EasyReader_${ShortVersion}.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1[0].release_date | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1[0].description | ConvertFrom-Html | Get-TextContent
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
