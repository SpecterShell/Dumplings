$RepoOwner = 'ip7z'
$RepoName = '7zip'
$Prefix = 'https://7-zip.org/a/'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'
$ShortVersion = $this.CurrentState.Version.Replace('.', '')

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'exe'
  InstallerUrl  = $Prefix + "7z${ShortVersion}.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = $Prefix + "7z${ShortVersion}-x64.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm'
  InstallerType = 'exe'
  InstallerUrl  = $Prefix + "7z${ShortVersion}-arm.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'exe'
  InstallerUrl  = $Prefix + "7z${ShortVersion}-arm64.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = $Prefix + "7z${ShortVersion}.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Prefix + "7z${ShortVersion}-x64.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions $MarkdigSoftlineBreakAsHardlineExtension
        $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("./h3[contains(., '$($this.CurrentState.Version)')]")
        if ($ReleaseNotesTitleNode) {
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.html_url
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
