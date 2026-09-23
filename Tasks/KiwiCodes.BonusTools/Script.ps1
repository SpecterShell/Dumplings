$Object1 = Invoke-WebRequest -Uri 'https://bonustools.kiwicodes.com/public/releases'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'msi'
  InstallerUrl  = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href -match 'KiwiCodesBonusTools' } catch {} }, 'First')[0].href | ConvertTo-UnescapedUri
}

# Version
$RawVersion = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:-\d+)+)').Groups[1].Value
$this.CurrentState.Version = $RawVersion.Replace('-', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesObject = ($Object1 | ConvertFrom-Html).SelectSingleNode("//main//section/div[contains(./p, 'Bonus Tools ${RawVersion}')]")
      if ($ReleaseNotesObject) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject.SelectNodes('./a[1]/following-sibling::node()') | Get-TextContent | Format-Text
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
