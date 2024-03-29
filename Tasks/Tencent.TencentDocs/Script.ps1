$Object1 = (
  Invoke-RestMethod -Uri 'https://docs.qq.com/rainbow/config.v2.ConfigService/PullConfigReq' -Method Post -Body (
    @{
      'pull_item'    = @{
        'app_id' = 'e4099bf9-f579-4233-9a15-6625a48bcb56'
        'group'  = 'Prod.Common.Update'
      }
      'client_infos' = @(
        @{
          'client_identified_name'  = 'uin'
          'client_identified_value' = '99'
        }
      )
    } | ConvertTo-Json -Compress
  ) -ContentType 'application/json'
).config.items.Where({ $_.group -eq 'Prod.Common.Update' }, 'First')[0].key_values.Where({ $_.key -eq 'update_info' }, 'First')[0].value | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.version

$ReleaseNotesContent = $Object1.update_info.Split("`n`n")[0] | Split-LineEndings

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesContent[0], '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $ReleaseNotesContent | Select-Object -Skip 2 | Format-Text
}

$Prefix = "https://dldir1v6.qq.com/weiyun/tencentdocs/electron-update/release/$($this.CurrentState.Version)/"

# Installer (x86)
$Object2 = Invoke-RestMethod -Uri "${Prefix}latest-win32-ia32.yml" | ConvertFrom-Yaml
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Prefix + $Object2.files[0].url
}

# Installer (x64)
$Object3 = Invoke-RestMethod -Uri "${Prefix}latest-win32-x64.yml" | ConvertFrom-Yaml
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Prefix + $Object3.files[0].url
}

# Installer (arm64)
# $Object4 = Invoke-RestMethod -Uri "${Prefix}latest-win32-arm64.yml" | ConvertFrom-Yaml
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'arm64'
#   InstallerUrl = $Prefix + $Object4.files[0].url
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
