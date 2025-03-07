$Object1 = Invoke-RestMethod -Uri 'https://support.freedomscientific.com/Downloads/OfflineInstallers/GetInstallers?product=Fusion&version=19&language=mul&releaseType=Offline' -UserAgent $DumplingsBrowserUserAgent

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrlX64 = $Object1.Where({ $_.InstallerPlatform -eq '64-bit' }, 'First')[0].InstallerLocationHTTP
}
$VersionX64 = [regex]::Match($InstallerUrlX64, '(\d+(?:\.\d+){3,})').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerUrlArm64 = $Object1.Where({ $_.InstallerPlatform -eq 'ARM64' }, 'First')[0].InstallerLocationHTTP
}
$VersionArm64 = [regex]::Match($InstallerUrlArm64, '(\d+(?:\.\d+){3,})').Groups[1].Value

if ($VersionX64 -ne $VersionArm64) {
  $this.Log("x64 version: ${VersionX64}")
  $this.Log("arm64 version: ${VersionArm64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $Object2 = Invoke-RestMethod -Uri 'https://support.freedomscientific.com/Downloads/Fusion/PreviousFeatures?version=2025' -UserAgent $DumplingsBrowserUserAgent | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("/h2[contains(text(), '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
