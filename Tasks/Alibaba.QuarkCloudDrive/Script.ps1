$Guid = (New-Guid).Guid
$Time = [System.DateTimeOffset]::Now.ToUnixTimeMilliseconds().ToString()
$Hash = [System.BitConverter]::ToString(
  [System.Security.Cryptography.MD5CryptoServiceProvider]::HashData(
    [System.Text.Encoding]::UTF8.GetBytes("${Guid}${Time}")
  )
).Replace('-', '').ToLower().Substring(0, 8)

$Prefix = "https://pan.quark.cn/update/win32/$($this.LastState.Version ?? '2.5.1')/"

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" -Headers @{
  'x-guid'        = $Guid
  'x-tm'          = $Time
  'authorization' = $Hash
} | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.releaseNotes | Format-Text
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
