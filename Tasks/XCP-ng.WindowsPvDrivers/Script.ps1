$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/xcp-ng/win-pv-drivers/releases/latest'

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('x64') -and $_.name -match 'Release' }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($Asset.name, '(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'wix'
  NestedInstallerFiles = @(
    [ordered]@{ RelativeFilePath = "xcpng-winpv-$($this.CurrentState.Version)-Release-x64/package/XenTools-x64.msi" }
  )
  InstallerUrl         = $Asset.browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.html_url
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
