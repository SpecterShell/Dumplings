# x64
$Object1 = Invoke-RestMethod -Uri 'https://releases.arc.net/windows/prod/Arc.appinstaller'
# arm64
$Object2 = Invoke-RestMethod -Uri 'https://releases.arc.net/windows/prod/Arc.arm64.appinstaller'

if ($Object1.AppInstaller.Version -ne $Object2.AppInstaller.Version) {
  $this.Log("x64 version: $($Object1.AppInstaller.Version)")
  $this.Log("arm64 version: $($Object2.AppInstaller.Version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.AppInstaller.Version
$ShortVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.' -replace '(\.0+)+$'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.AppInstaller.MainPackage.Uri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object2.AppInstaller.MainPackage.Uri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://arc.net/windows/release-notes' | Join-String -Separator "`n" | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//p[contains(text(), 'V${ShortVersion}') or contains(text(), 'V.${ShortVersion}')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./preceding-sibling::h2[1]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
