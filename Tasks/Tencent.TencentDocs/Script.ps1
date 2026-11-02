$Object1 = Invoke-RestMethod -Uri 'https://docs.qq.com/rainbow/config.v2.ConfigService/PullConfigReq' -Method Post -Body (
  @{
    pull_item = @{
      app_id  = 'e4099bf9-f579-4233-9a15-6625a48bcb56'
      group   = 'Prod.Common.AutoUpdate'
      envName = 'Default'
    }
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'
$Object2 = $Object1.config.items.Where({ $_.group -eq 'Prod.Common.AutoUpdate' })[0].key_values.Where({ $_.key -eq 'app.yaml' }, 'First')[0].value | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object2.channelMap.'30001'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://docs.qq.com/api/package/get?channel_id=30001&version_id=latest&package_name=TencentDocs-x86_64.exe'
  # InstallerUrl = "https://docs.qq.com/api/package/get?channel_id=30001&version_id=$($this.CurrentState.Version)&package_name=TencentDocs-x86_64.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = 'https://docs.qq.com/api/package/get?channel_id=30001&version_id=latest&package_name=TencentDocs-arm64.exe'
  # InstallerUrl = "https://docs.qq.com/api/package/get?channel_id=30001&version_id=$($this.CurrentState.Version)&package_name=TencentDocs-arm64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
