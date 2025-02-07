$Object1 = Invoke-RestMethod -Uri 'https://www.privateinternetaccess.com/clients/desktop/release'

if ($Object1.latest_version_piax.windows_x64.version -ne $Object1.latest_version_piax.windows_x86.version) {
  $this.Log("x86 version: $($Object1.latest_version_piax.windows_x86.version)")
  $this.Log("x64 version: $($Object1.latest_version_piax.windows_x64.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.latest_version_piax.windows_x64.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.latest_version_piax.windows_x86.download
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.latest_version_piax.windows_x64.download
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = 'https://www.privateinternetaccess.com/pages/changelog'
      }

      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//article[@class='changelog-release']/h3[contains(text(), 'v$($this.CurrentState.Version.Split('+')[0])')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::h4[contains(text(), "Release Date")]').InnerText,
          '([a-zA-Z]+\W+\d{1,2}\W+\d{4})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::*[@class="log-list"]') | Get-TextContent | Format-Text
        }

        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $ReleaseNotesUrl + '#v' + $this.CurrentState.Version.Split('+')[0]
        }
      } else {
        $this.Log("No ReleaseTime, ReleaseNotes (en-US) and ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
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
