$Object1 = Invoke-WebRequest -Uri 'https://support.isabel.eu/en-US/downloadzone/downloadzone_windows/'

# x86
$InstallerLink = $Object1.Links.Where({ try { $_.outerHTML.Contains('Isabel Security Components') -and $_.href.EndsWith('.msi') -and $_.href.Contains('x86') } catch {} }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerLink.href
}
$VersionX86 = [regex]::Match($InstallerLink.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value

# x64
$InstallerLink = $Object1.Links.Where({ try { $_.outerHTML.Contains('Isabel Security Components') -and $_.href.EndsWith('.msi') -and $_.href.Contains('x64') } catch {} }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerLink.href
}
$VersionX64 = [regex]::Match($InstallerLink.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("Inconsistent versions: x86: ${VersionX86}, x64: ${VersionX64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://support.isabel.eu/en-US/security_components/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
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
