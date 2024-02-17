$Guid = (New-Guid).Guid
$Time = [System.DateTimeOffset]::Now.ToUnixTimeMilliseconds().ToString()
$Hash = [System.BitConverter]::ToString(
  [System.Security.Cryptography.MD5CryptoServiceProvider]::HashData(
    [System.Text.Encoding]::UTF8.GetBytes("${Guid}${Time}")
  )
).Replace('-', '').ToLower().Substring(0, 8)

$this.CurrentState = Invoke-RestMethod -Uri "https://pan.quark.cn/update/win32/$($this.LastState.Version ?? '2.5.1')/latest.yml" -Headers @{
  'x-guid'        = $Guid
  'x-tm'          = $Time
  'authorization' = $Hash
} | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
