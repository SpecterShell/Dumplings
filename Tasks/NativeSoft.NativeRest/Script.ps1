$Object1 = Invoke-RestMethod -Uri 'https://nativesoft.com/api/releases.check' -Method Post -Body (
  @{
    product      = 'NativeRest'
    version      = $this.Status.Contains('New') ? '2.1.7' : $this.LastState.Version
    platform     = 'Windows'
    architecture = 'Intel'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://nativesoft.com/changelog' | ConvertFrom-Html

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object2.SelectSingleNode("//h2[@id='release$($this.CurrentState.Version.Replace('.', ''))header']").InnerText,
        '([a-zA-Z]+\W+\d{1,2}\W+\d{4})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectSingleNode("//div[@id='release$($this.CurrentState.Version.Replace('.', ''))features']") | Get-TextContent | Format-Text
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
