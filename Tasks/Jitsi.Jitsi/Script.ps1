# The properties file is the update feed the app itself polls; its download_link
# points at a dead download.jitsi.org path, so installer URLs come from the
# GitHub stable release the download page links.
$Object1 = Invoke-RestMethod -Uri 'https://download.jitsi.org/jitsi/windows/versionupdate.properties' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.'_'.last_version

$Release = Invoke-GitHubApi -Uri "https://api.github.com/repos/jitsi/jitsi/releases/tags/Jitsi-$($this.CurrentState.Version.Split('.')[0..1] -join '.')"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = $Release.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('x86') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Release.assets.Where({ $_.name.EndsWith('.msi') -and $_.name.Contains('x64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Release.published_at

      if (-not [string]::IsNullOrWhiteSpace($Release.body)) {
        $ReleaseNotesObject = $Release.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        $Skip = $false
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node; $Node = $Node.NextSibling) {
          if ($Node.Name -in @('h1')) {
            $Skip = $Node.InnerText -match 'Downloads'
          }
          if (-not $Skip) { $Node }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Release.html_url
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
