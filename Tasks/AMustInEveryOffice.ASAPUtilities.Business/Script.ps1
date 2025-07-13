# Installer
# User
$this.CurrentState.Installer += [ordered]@{
  Scope        = 'user'
  InstallerUrl = $InstallerUserUrl = $Global:DumplingsStorage.ASAPUtilitiesDownloadPage.Links.Where({ try { $_.href.EndsWith('.exe') -and -not $_.href.Contains('HS') -and $_.href.Contains('NoAdmin') } catch {} }, 'First')[0].href
}
$VersionUser = [regex]::Match($InstallerUserUrl, '(\d+(?:-\d+)+)').Groups[1].Value.Replace('-', '.')

# Machine
$this.CurrentState.Installer += [ordered]@{
  Scope        = 'machine'
  InstallerUrl = $InstallerMachineUrl = $Global:DumplingsStorage.ASAPUtilitiesDownloadPage.Links.Where({ try { $_.href.EndsWith('.exe') -and -not $_.href.Contains('HS') -and -not $_.href.Contains('NoAdmin') } catch {} }, 'First')[0].href
}
$VersionMachine = [regex]::Match($InstallerMachineUrl, '(\d+(?:-\d+)+)').Groups[1].Value.Replace('-', '.')

if ($VersionUser -ne $VersionMachine) {
  $this.Log("Inconsistent versions: user: ${VersionUser}, machine: ${VersionMachine}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionMachine

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = (Invoke-RestMethod -Uri 'https://www.asap-utilities.com/rss.php').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object3) {
        $ReleaseNotesObject = $Object3[0].description.'#cdata-section' | ConvertFrom-Html

        # Remove download section
        $SectionTitleNode = $ReleaseNotesObject.SelectSingleNode('./h3[contains(text(), "Download Now")]')
        $Nodes = for ($Node = $SectionTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        $SectionTitleNode.Remove()
        $Nodes.ForEach({ $_.Remove() })

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
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
