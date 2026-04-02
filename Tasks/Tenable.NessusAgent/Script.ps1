$Object1 = (Invoke-WebRequest -Uri 'https://www.tenable.com/downloads/api/v2/pages/nessus-agents').Content | ConvertFrom-Json -AsHashtable
$Object2 = $Object1.releases[$Object1.releases.latest.Keys.Where({ $_.StartsWith('Nessus Agents') }, 'First')[0]]
# x86
# $Object3 = $Object2.Where({ $_.file.EndsWith('.msi') -and $_.file.Contains('Win32') }, 'First')[0]
# x64
$Object4 = $Object2.Where({ $_.file.EndsWith('.msi') -and $_.file.Contains('x64') }, 'First')[0]

# if ($Object3.version -ne $Object4.version) {
#   $this.Log("x86 version: $($Object3.version)")
#   $this.Log("x64 version: $($Object4.version)")
#   throw 'Inconsistent versions detected'
# }

# Version
$this.CurrentState.Version = $Object4.version

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = $Object3.file_url
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object4.file_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object4.product_release_date.ToUniversalTime()

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://docs.tenable.com/release-notes/Content/agent/agent.htm'
      }

      $ReleaseNotesUrl = "https://docs.tenable.com/release-notes/Content/agent/$($this.CurrentState.ReleaseTime.Year).htm"
      $Object5 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html
      $ReleaseNotesTitleNode = $Object5.SelectSingleNode("//h2[contains(., 'Tenable Agent $($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotesUrl (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotesUrl'
          Value  = $ReleaseNotesUrl
        }

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
