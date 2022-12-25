$Guid = (New-Guid).Guid
$Time = [System.DateTimeOffset]::Now.ToUnixTimeMilliseconds().ToString()
$Hash = [System.BitConverter]::ToString(
  [System.Security.Cryptography.MD5CryptoServiceProvider]::HashData(
    [System.Text.Encoding]::UTF8.GetBytes("${Guid}${Time}")
  )
).Replace('-', '').ToLower().Substring(0, 8)

$Task.CurrentState = Invoke-RestMethod -Uri "https://pan.quark.cn/update/win32/$($Task.LastState.Version ?? '2.5.1')/latest.yml" -Headers @{
  'x-guid'        = $Guid
  'x-tm'          = $Time
  'authorization' = $Hash
} | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

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
