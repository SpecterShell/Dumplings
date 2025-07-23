$Object1 = Invoke-RestMethod -Uri 'https://go.microsoft.com/fwlink/?linkid=2274438'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$Asset = $Object1.assets.Where({ $_.platform -eq 'win32-x64-user' }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  Scope           = 'user'
  InstallerUrl    = Get-RedirectedUrl -Uri $Asset.url
  InstallerSha256 = $Asset.sha256hash.ToUpper()
}
$Asset = $Object1.assets.Where({ $_.platform -eq 'win32-x64' }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  Scope           = 'machine'
  InstallerUrl    = Get-RedirectedUrl -Uri $Asset.url
  InstallerSha256 = $Asset.sha256hash.ToUpper()
}
$Asset = $Object1.assets.Where({ $_.platform -eq 'win32-arm64-user' }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  Scope           = 'user'
  InstallerUrl    = Get-RedirectedUrl -Uri $Asset.url
  InstallerSha256 = $Asset.sha256hash.ToUpper()
}
$Asset = $Object1.assets.Where({ $_.platform -eq 'win32-arm64' }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  Scope           = 'machine'
  InstallerUrl    = Get-RedirectedUrl -Uri $Asset.url
  InstallerSha256 = $Asset.sha256hash.ToUpper()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = 'https://github.com/microsoft/azuredatastudio/releases'
      }

      $RepoOwner = 'microsoft'
      $RepoName = 'azuredatastudio'

      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/tags/$($this.CurrentState.Version)"

      # if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
      #   # ReleaseNotes (en-US)
      #   $this.CurrentState.Locale += [ordered]@{
      #     Locale = 'en-US'
      #     Key    = 'ReleaseNotes'
      #     Value  = $Object2.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
      #   }
      # } else {
      #   $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      # }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object2.html_url
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
