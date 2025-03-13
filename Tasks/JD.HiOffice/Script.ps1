$Object1 = Invoke-RestMethod -Uri 'https://hio-api.jd.com/rest/v1/clientver/check/upgrade' -Method Post -Headers @{
  'X-DeviceUuid'    = (New-Guid).Guid.Replace('-', '').ToLower()
  'X-Timestamp'     = [System.DateTimeOffset]::Now.ToUnixTimeMilliseconds()
  'X-TenantCode'    = 'CN.JD.GROUP'
  'X-ClientFlag'    = '01'
  'X-ClientVersion' = $this.Status.Contains('New') ? $this.LastState.Version.Replace('.', '') : '3099'
  'X-OS'            = 'windows'
} -Body '{}' -ContentType 'application/json'

if ($Object1.content.needUpgrade -eq 0) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$RawVersionLength = $Object1.content.clientVersion.ToString().Length
$this.CurrentState.Version = $Object1.content.clientVersion.ToString().Insert($RawVersionLength - 1, '.').Insert($RawVersionLength - 2, '.').Insert($RawVersionLength - 3, '.')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.content.files.Where({ $_.fileType -eq '.exe' })[0].fileUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.content.updateTime | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.content.remark | Format-Text
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
