$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/mgba-emu/mgba/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('-win32-installer.exe') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerUrl  = $Object1.assets.Where({ $_.name.EndsWith('-win64-installer.exe') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()
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
