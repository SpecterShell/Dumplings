Set-StrictMode -Version 3.0

# x64
$Object1 = Invoke-RestMethod `
  -Uri 'https://interface.music.163.com/api/pc/upgrade/get' `
  -Method Post `
  -Headers @{ Cookie = 'osver=Microsoft-Windows-10; appver=3.0.1.201499' } `
  -Body 'action=manual&cpuBitWidth=64&e_r=false'
$Version1 = "$($Object1.data.packageVO.appver).$($Object1.data.packageVO.buildver)"
$InstallerUrl1 = $Object1.data.packageVO.downloadUrl

# x86
$Object2 = Invoke-RestMethod `
  -Uri 'https://interface.music.163.com/api/pc/upgrade/get' `
  -Method Post `
  -Headers @{ Cookie = 'osver=Microsoft-Windows-10; appver=3.0.1.201499' } `
  -Body 'action=manual&cpuBitWidth=32&e_r=false'
$Version2 = "$($Object2.data.packageVO.appver).$($Object2.data.packageVO.buildver)"
$InstallerUrl2 = $Object2.data.packageVO.downloadUrl


$Identical = $true
if ($Version1 -ne $Version2) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
}

# Version
$this.CurrentState.Version = $Version1

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl2
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl1
}

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = '"' + $Object1.data.upgradeContent + '"' | ConvertFrom-Json | Format-Text
}

Set-StrictMode -Off

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 -and $Identical }) {
    $this.Submit()
  }
}
