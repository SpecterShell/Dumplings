$Object1 = Invoke-RestMethod -Uri 'https://static.devin.ai/cli/current/manifest.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerUrl    = $Object1.platforms.'x86_64-pc-windows'.url
  InstallerSha256 = $Object1.platforms.'x86_64-pc-windows'.sha256.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  InstallerUrl    = $Object1.platforms.'aarch64-pc-windows'.url
  InstallerSha256 = $Object1.platforms.'aarch64-pc-windows'.sha256.ToUpper()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://cli.devin.ai/docs/changelog/stable' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[contains(@id, '$($this.CurrentState.Version.Replace('.', '-'))')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div[last()]') | Get-TextContent | Format-Text
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
