# x86
$Object1 = Invoke-RestMethod -Uri 'https://www.airserver.com/downloads/pc/appcast.xml' -UserAgent 'AirServer? Windows/10.0.22000 (x86)' -SkipHeaderValidation
# x64
$Object2 = Invoke-RestMethod -Uri 'https://www.airserver.com/downloads/pc/appcast-x64.xml' -UserAgent 'AirServer? Windows/10.0.22000 (x64)' -SkipHeaderValidation

# Version
$this.CurrentState.Version = $Object2.enclosure.version

if ($Object1.enclosure.version -ne $Object2.enclosure.version) {
  $this.Log("Inconsistent versions: x86: $($Object1.enclosure.version), x64: $($Object2.enclosure.version)", 'Error')
  return
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = Join-Uri $Object1.enclosure.url "AirServer-$($this.CurrentState.Version)-x86.msi"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = $Object1.enclosure.primaryInstallationFile
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = Join-Uri $Object2.enclosure.url "AirServer-$($this.CurrentState.Version)-x64.msi"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = $Object2.enclosure.primaryInstallationFile
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.pubDate | Get-Date -AsUTC

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object2.releaseNotesLink
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesNode = $Object3.SelectSingleNode("//table[contains(., 'Version $($this.CurrentState.Version)')][1]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./tr[2]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
