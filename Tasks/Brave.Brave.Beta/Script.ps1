$RepoOwner = 'brave'
$RepoName = 'brave-browser'

$Object1 = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases").Where({ $_.name.StartsWith('Beta') })

# Version
$this.CurrentState.Version = "$([regex]::Match($Object1.name, 'Chromium (\d+)').Groups[1].Value).$([regex]::Match($Object1.name, 'v(\d+(?:\.\d+)+)').Groups[1].Value)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  Scope        = 'user'
  InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Standalone') -and $_.name.EndsWith('Setup32.exe') -and $_.name.Contains('Silent') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  Scope        = 'machine'
  InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Standalone') -and $_.name.EndsWith('Setup32.exe') -and -not $_.name.Contains('Silent') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'user'
  InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Standalone') -and $_.name.EndsWith('Setup.exe') -and $_.name.Contains('Silent') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  Scope        = 'machine'
  InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Standalone') -and $_.name.EndsWith('Setup.exe') -and -not $_.name.Contains('Silent') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'user'
  InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Standalone') -and $_.name.EndsWith('SetupArm64.exe') -and $_.name.Contains('Silent') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  Scope        = 'machine'
  InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Standalone') -and $_.name.EndsWith('SetupArm64.exe') -and -not $_.name.Contains('Silent') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
