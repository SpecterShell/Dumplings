$RepoOwner = 'brave'
$RepoName = 'brave-browser'

$Releases = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases").Where({ $_.name.StartsWith('Beta') })

# The latest release may not contain all the installers. Iterate through the releases to find the latest one with all installers.
foreach ($Object1 in $Releases) {
  try {
    # Version
    $this.CurrentState.Version = "$([regex]::Match($Object1.name, 'Chromium (\d+)').Groups[1].Value).$([regex]::Match($Object1.name, 'v(\d+(?:\.\d+)+)').Groups[1].Value)"

    # Installer
    $this.CurrentState.Installer = @(
      [ordered]@{
        Architecture = 'x86'
        Scope        = 'user'
        InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Standalone') -and $_.name.EndsWith('Setup32.exe') -and $_.name.Contains('Silent') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
      }
      [ordered]@{
        Architecture = 'x86'
        Scope        = 'machine'
        InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Standalone') -and $_.name.EndsWith('Setup32.exe') -and -not $_.name.Contains('Silent') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
      }
      [ordered]@{
        Architecture = 'x64'
        Scope        = 'user'
        InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Standalone') -and $_.name.EndsWith('Setup.exe') -and $_.name.Contains('Silent') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
      }
      [ordered]@{
        Architecture = 'x64'
        Scope        = 'machine'
        InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Standalone') -and $_.name.EndsWith('Setup.exe') -and -not $_.name.Contains('Silent') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
      }
      [ordered]@{
        Architecture = 'arm64'
        Scope        = 'user'
        InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Standalone') -and $_.name.EndsWith('SetupArm64.exe') -and $_.name.Contains('Silent') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
      }
      [ordered]@{
        Architecture = 'arm64'
        Scope        = 'machine'
        InstallerUrl = $Object1.assets.Where({ $_.name.Contains('Standalone') -and $_.name.EndsWith('SetupArm64.exe') -and -not $_.name.Contains('Silent') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
      }
    )

    # If the latest release contains all installers, break the loop and use this release.
    break
  } catch {}
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
