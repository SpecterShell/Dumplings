$Object1 = Invoke-RestMethod -Uri 'https://ide.ap-southeast-1.myhuaweicloud.com/v1/release-info/latest?sub_product_name=ai&os_type=windows&is_server=false&arch=X86-64' -Headers @{
  'X-Language'       = 'en'
  'x-requested-with' = 'XMLHttpRequest'
}

# Version
$this.CurrentState.Version = $Object1.result.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'inno'
  InstallerUrl  = $Object1.result.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.result.release_time | Get-Date -AsUTC
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
