$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/fluent/fluent-bit/releases/latest'

# Version
$this.CurrentState.Version = $Object1.tag_name -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = "https://packages.fluentbit.io/windows/fluent-bit-$($this.CurrentState.Version)-win32.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = "https://packages.fluentbit.io/windows/fluent-bit-$($this.CurrentState.Version)-win64.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'nullsoft'
  InstallerUrl  = "https://packages.fluentbit.io/windows/fluent-bit-$($this.CurrentState.Version)-winarm64.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerType        = 'zip'
  NestedInstallerType  = 'portable'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "fluent-bit-$($this.CurrentState.Version)-win32\bin\fluent-bit.exe" })
  InstallerUrl         = "https://packages.fluentbit.io/windows/fluent-bit-$($this.CurrentState.Version)-win32.zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'portable'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "fluent-bit-$($this.CurrentState.Version)-win64\bin\fluent-bit.exe" })
  InstallerUrl         = "https://packages.fluentbit.io/windows/fluent-bit-$($this.CurrentState.Version)-win64.zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'portable'
  NestedInstallerFiles = @([ordered]@{ RelativeFilePath = "fluent-bit-$($this.CurrentState.Version)-winarm64\bin\fluent-bit.exe" })
  InstallerUrl         = "https://packages.fluentbit.io/windows/fluent-bit-$($this.CurrentState.Version)-winarm64.zip"
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
