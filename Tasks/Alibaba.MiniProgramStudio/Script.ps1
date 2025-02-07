$Object1 = Invoke-RestMethod -Uri 'https://hpmweb.alipay.com/tinyApp/queryAppUpdate/latest.yml?productId=TINY_APP_IDE_WINDOWS&productVersion=1.0.0&osType=ANDROID&forceCheckByUser=true' | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.path.Trim()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = ($Object1.guideMemo | Convert-MarkdownToHtml | Get-TextContent) -creplace '^\d+\.\d+\.\d+\n', '' | Format-Text
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
