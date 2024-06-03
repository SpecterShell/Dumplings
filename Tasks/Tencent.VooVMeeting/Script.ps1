$Object1 = Invoke-RestMethod -Uri 'https://voovmeeting.com/wemeet-webapi/v2/config/query-download-info' -Method Post -Body (
  @{
    instance = 'windows'
    type     = '1410000197'
  } | ConvertTo-Json -Compress -AsArray
)

# Version
$this.CurrentState.Version = $Object1.data[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data[0].url.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.data[0].sub_date | Get-Date -Format 'yyyy-MM-dd'
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
