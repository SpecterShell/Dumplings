$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://zcode-ai.com/api/v2/releases/latest?target=windows&arch=x86_64' | Join-String -Separator "`n" | ConvertFrom-Json
$Object2 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://zcode-ai.com/api/v2/releases/latest?target=windows&arch=aarch64' | Join-String -Separator "`n" | ConvertFrom-Json

if ($Object1.version -ne $Object2.version) {
  $this.Log("Inconsistent versions: x64: $($Object1.version), arm64: $($Object2.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.installer_url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object2.installer_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at | ConvertFrom-UnixTimeMilliseconds
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-RestMethod -Uri $Object1.changelog_url | ConvertFrom-Yaml

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object3.releaseNotes | Convert-MarkdownToHtml | Get-TextContent | Format-Text
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
