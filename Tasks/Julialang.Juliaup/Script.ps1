$RepoOwner = 'JuliaLang'
$RepoName = 'juliaup'

$Object1 = Invoke-RestMethod -Uri 'https://install.julialang.org/Julia.appinstaller'

$Prefix = $Object1.AppInstaller.MainBundle.Uri | Split-Uri -Parent

$BundleFile = Get-TempFile -Uri $Object1.AppInstaller.MainBundle.Uri
$Object2 = 7z.exe e -y -so $BundleFile 'AppxMetadata\AppxBundleManifest.xml' | ConvertFrom-Xml
Remove-Item -Path $BundleFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

# Version
$this.CurrentState.Version = $Object2.Bundle.Identity.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $Object2.Bundle.Packages.Package.Where({ $_.Architecture -eq 'x86' }, 'First')[0].FileName
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + $Object2.Bundle.Packages.Package.Where({ $_.Architecture -eq 'x64' }, 'First')[0].FileName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/tags/v$($this.CurrentState.Version.Split('.')[0..2] -join '.')"

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object2.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object2.html_url
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }
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
