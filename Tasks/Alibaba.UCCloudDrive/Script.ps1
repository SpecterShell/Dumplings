$Guid = (New-Guid).Guid
$Time = [System.DateTimeOffset]::Now.ToUnixTimeMilliseconds().ToString()
$Hash = [System.BitConverter]::ToString(
  [System.Security.Cryptography.MD5CryptoServiceProvider]::HashData(
    [System.Text.Encoding]::UTF8.GetBytes("${Guid}${Time}")
  )
).Replace('-', '').ToLower().Substring(0, 8)

$this.CurrentState = Invoke-RestMethod -Uri "https://drive.uc.cn/update/win32/x64/$($this.LastState.Contains('Version') ? $this.LastState.Version : '2.5.1')/latest.yml" -Headers @{
  'x-guid'        = $Guid
  'x-tm'          = $Time
  'authorization' = $Hash
} | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

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
