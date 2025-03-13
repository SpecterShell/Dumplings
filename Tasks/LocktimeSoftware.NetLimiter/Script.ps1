$Object1 = Invoke-RestMethod -Uri 'https://netlimiter.com/versionchecker' -Body @{
  product = 'nl'
  version = $this.Status.Contains('New') ? '5.3.17.0' : $this.LastState.Version
} | ConvertFrom-StringData -Delimiter ':'

if (-not $Object1.Contains('version')) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.fileUrl
  ProductCode  = "NetLimiter $($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object1.infoUrl
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.SelectSingleNode('//div[@class="container"]/div[1]/span').InnerText | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      # Remove download button
      $Object2.SelectNodes('.//a[contains(@class, "btn")]').ForEach({ $_.Remove() })
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('//div[@class="container"]/div[1]/following-sibling::node()') | Get-TextContent | Format-Text
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
