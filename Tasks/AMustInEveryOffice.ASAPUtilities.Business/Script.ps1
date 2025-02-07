# User
$Object1 = Invoke-WebRequest -Uri 'https://www.asap-utilities.com/download-asap-utilities-excel.php?file=51'
$Version1 = [regex]::Match($Object1.Content, 'ASAP Utilities (\d+(?:\.\d+){2,})').Groups[1].Value

# Machine
$Object2 = Invoke-WebRequest -Uri 'https://www.asap-utilities.com/download-asap-utilities-excel.php?file=21'
$Version2 = [regex]::Match($Object2.Content, 'ASAP Utilities (\d+(?:\.\d+){2,})').Groups[1].Value

if ($Version1 -ne $Version2) {
  $this.Log("User version: ${Version1}")
  $this.Log("Machine version: ${Version2}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Version2

# Installer
$this.CurrentState.Installer += [ordered]@{
  Scope        = 'user'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('server1') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  Scope        = 'machine'
  InstallerUrl = $Object2.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('server1') } catch {} }, 'First')[0].href
}

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
