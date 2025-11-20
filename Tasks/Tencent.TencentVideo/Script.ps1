$Prefix = 'https://v.qq.com/download.html'
$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html
$Object2 = Invoke-RestMethod -Uri (Join-Uri $Prefix $Object1.SelectSingleNode('//script[contains(@src, "index") and contains(@src, ".js")]').Attributes['src'].Value)
$SchemaKey = [regex]::Match($Object2, 'schemaid:"downloadpage_config",schemakey:"([^"]+)"').Groups[1].Value
$Object3 = (Invoke-RestMethod -Uri "https://cache.wuji.qq.com/x/api/wuji_cache/object?appid=vqqcom&schemaid=downloadpage_config&schemakey=${SchemaKey}").data.Where({ $_.app -eq 'Windows' }, 'First')[0]

# Version
$this.CurrentState.Version = $Object3.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object3.downloadLink
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.updateDate.ToUniversalTime()

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object3.versionDetail | Format-Text
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
