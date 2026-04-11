$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/caomengxuan666/WinuxCmd/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name -match 'win' -and $_.name.Contains('x64') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = $Asset.browser_download_url | ConvertTo-UnescapedUri
}
$Asset = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name -match 'win' -and $_.name.Contains('arm64') }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'arm64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = $Asset.browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      # if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
      #   # ReleaseNotes (en-US)
      #   $this.CurrentState.Locale += [ordered]@{
      #     Locale = 'en-US'
      #     Key    = 'ReleaseNotes'
      #     Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
      #   }
      # } else {
      #   $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      # }

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

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
      $Installer['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.Name -ceq 'winuxcmd.exe' }, 'First')[0].FullName.Replace('/', '\') })
      $ZipFile.Dispose()
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
