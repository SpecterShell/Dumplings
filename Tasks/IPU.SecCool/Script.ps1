$Object1 = Invoke-WebRequest -Uri 'https://www.ipu.dk/products/seccool/'

# x86
$InstallerLink = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and -not $_.href.Contains('x64') } catch {} }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerLink.href
}
$VersionX86 = [regex]::Match($InstallerLink.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value

# x64
$InstallerLink = $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x64') } catch {} }, 'First')[0]
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
      $Object2 = $Object1 | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//*[(self::h3 or self::h4) and contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -notmatch 'h\d'; $Node = $Node.NextSibling) { $Node }
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

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
