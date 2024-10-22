$Object1 = Invoke-RestMethod -Uri 'https://www.eeo.cn/sysshare/custom/download_conf.json'

# Version
$this.CurrentState.Version = $Object1.Where({ $_.id -eq 81 }, 'First')[0].confValue

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https:' + $Object1.Where({ $_.id -eq 3 }, 'First')[0].confValue
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.Where({ $_.id -eq 3 }, 'First')[0].updatedTime | ConvertFrom-UnixTimeSeconds
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
