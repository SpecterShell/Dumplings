# x64
$Object1 = @(Invoke-RestMethod -Uri "https://www.wireshark.org/update/0/Wireshark/$($this.Status.Contains('New') ? '4.4.5' : $this.LastState.Version)/Windows/x86-64/en-US/stable.xml")
# arm64
$Object2 = @(Invoke-RestMethod -Uri "https://www.wireshark.org/update/0/Wireshark/$($this.Status.Contains('New') ? '4.4.5' : $this.LastState.Version)/Windows/arm64/en-US/stable.xml")

if ($Object1[0].enclosure.version -ne $Object2[0].enclosure.version) {
  $this.Log("x64 version: $($Object1[0].enclosure.version)")
  $this.Log("arm64 version: $($Object2[0].enclosure.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1[0].enclosure.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1[0].enclosure.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Object1[0].enclosure.url -replace '\.exe$', '.msi'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object2[0].enclosure.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1[0].pubDate | Get-Date -AsUTC

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object1[0].releaseNotesLink
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object3.SelectSingleNode('//h2[@id="_whats_new"]/following-sibling::div[@class="sectionbody"]') | Get-TextContent | Format-Text
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
