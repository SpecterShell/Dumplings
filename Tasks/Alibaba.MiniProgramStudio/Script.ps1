$Object = Invoke-RestMethod -Uri 'https://hpmweb.alipay.com/tinyApp/queryAppUpdate/latest.yml?productId=TINY_APP_IDE_WINDOWS&productVersion=1.0.0&osType=ANDROID&forceCheckByUser=true' | ConvertFrom-Yaml

# Version
$Task.CurrentState.Version = $Object.version

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.path.Trim()
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = ($Object.guideMemo | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent | Format-Text
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
