# Inno
$Object1 = Invoke-RestMethod -Uri 'https://assets.alfaview.com/stable/win/version.info'
# WiX
$Object2 = Invoke-RestMethod -Uri 'https://assets.alfaview.com/stable/win/msi_version.info'

if ($Object1.versions[0].version -ne $Object2.versions[0].version) {
  $this.Log("Inconsistent versions: Inno: $($Object1.versions[0].version), WiX: $($Object2.versions[0].version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.versions[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = Join-Uri 'https://assets.alfaview.com/stable/win/' $Object1.versions[0].download_url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri 'https://assets.alfaview.com/stable/win/' $Object2.versions[0].download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.versions[0].'build-date' | Get-Date | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://support.alfaview.com/en/release-notes/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[contains(@id, '$($this.CurrentState.Version.Replace('.', '-'))')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://support.alfaview.com/release-notes/' + '#' + $ReleaseNotesTitleNode.Attributes['id'].Value
        }

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::figure[1]//tr').ForEach({ "[$($_.SelectSingleNode('./td[1]') | Get-TextContent)] $($_.SelectSingleNode('./td[2]') | Get-TextContent)" }) | Format-Text
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
