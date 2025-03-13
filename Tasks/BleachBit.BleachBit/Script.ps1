$Object1 = Invoke-RestMethod -Uri "https://update.bleachbit.org/update/$($this.Status.Contains('New') ? $this.LastState.Version : '4.5.0')"

if ($Object1.SelectSingleNode('//latest-version')) {
  # Version
  $this.CurrentState.Version = $Object1.updates.'latest-version'
} else {
  # Version
  $this.CurrentState.Version = $Object1.updates.stable.ver
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.bleachbit.org/BleachBit-$($this.CurrentState.Version)-setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object1.updates.stable.'#text' | Split-Uri -LeftPart Path
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = ($InstallerFile | Read-ProductVersionFromExe).Split('.')[0..3] -join '.'

    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode('//div[contains(@class, "field-item")]/h3[contains(., "Changes") or contains(., "Known issues")]')
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode; $Node -and -not ($Node.Name -eq 'h3' -and $Node.InnerText.Contains('Download')); $Node = $Node.NextSibling) { $Node }

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
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
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
