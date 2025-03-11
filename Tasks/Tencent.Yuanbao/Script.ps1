$WebSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
$null = Invoke-RestMethod -Uri 'https://yuanbao.tencent.com/api/anon/login' -Method Post -Headers @{ Cookie = 'hy_source=web' } -Body (
  @{
    device_id   = (New-Guid).Guid
    device_type = 1
  } | ConvertTo-Json -Compress
) -ContentType 'application/json' -WebSession $WebSession
$Object2 = Invoke-RestMethod -Uri 'https://yuanbao.tencent.com/api/info/general' -WebSession $WebSession

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.appBaseConfig.pcDownloadUrl.windows
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'yuanbao_(\d+\.\d+\.\d+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object2.appBaseConfig.updateContext | Format-Text
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
