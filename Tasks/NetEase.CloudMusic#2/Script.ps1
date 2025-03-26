$Object1 = Invoke-RestMethod `
  -Uri 'https://interface.music.163.com/api/pc/upgrade/get' `
  -Method Post `
  -Headers @{ Cookie = 'osver=Microsoft-Windows-10; appver=0.0' } `
  -Body 'action=manual&cpuBitWidth=32&e_r=false'

# Version
$this.CurrentState.Version = "$($Object1.data.packageVO.appver).$($Object1.data.packageVO.buildver)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.packageVO.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = '"' + $Object1.data.upgradeContent + '"' | ConvertFrom-Json | Format-Text
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
