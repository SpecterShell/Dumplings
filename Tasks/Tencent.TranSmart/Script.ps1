$Object1 = Invoke-RestMethod -Uri 'https://transmart.qq.com/api/resourcemanageserver/findAllClientVersion' -Method Post -Body (
  @{
    value = 'TranSmart'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.value.windows[0].version, '(Alpha[\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.value.windows[0].url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.value.windows[0].publish_time | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.value.windows[0].describe_content | Format-Text
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
