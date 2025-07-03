$Object1 = Invoke-WebRequest -Uri 'https://www.urbackup.org/download.html'

# Installer
$this.CurrentState.Installer += $InstallerEXE = [ordered]@{
  InstallerType = 'nullsoft'
  InstallerUrl  = 'https:' + $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('Client') } catch {} }, 'First')[0].href | ConvertTo-UnescapedUri
}
$VersionEXE = [regex]::Match($InstallerEXE.InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerMSI = [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = 'https:' + $Object1.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains('Client') } catch {} }, 'First')[0].href | ConvertTo-UnescapedUri
}
$VersionMSI = [regex]::Match($InstallerMSI.InstallerUrl, '(\d+(\.\d+)+)').Groups[1].Value

if ($VersionEXE -ne $VersionMSI) {
  $this.Log("EXE version: ${VersionEXE}")
  $this.Log("MSI version: ${VersionMSI}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionEXE

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.urbackup.org/client_changelog.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
