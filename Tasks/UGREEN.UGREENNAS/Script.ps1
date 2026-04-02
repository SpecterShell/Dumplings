$Object1 = Invoke-RestMethod -Uri 'https://cloud.ugreengroup.com/api/system/v1/softVer/latest' -Method Post -Body (
  @{
    appNo = 'com.ugreenNas.win'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

# Version
$this.CurrentState.Version = $Object1.data.verName -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.pkgUrl -replace '//dl-ugos.ugnas.com/', '//oss-ugos.ugreengroup.com/'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data.pubTime | ConvertFrom-UnixTimeMilliseconds

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.desc | Format-Text
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
