# Upgrade x64
$Object1 = Invoke-RestMethod `
  -Uri 'https://interface.music.163.com/api/pc/upgrade/get' `
  -Method Post `
  -Headers @{ Cookie = 'osver=Microsoft-Windows-10; appver=0.0' } `
  -Body 'action=manual&cpuBitWidth=64&e_r=false'
$Version1 = "$($Object1.data.packageVO.appver).$($Object1.data.packageVO.buildver)"
$InstallerUrl1 = $Object1.data.packageVO.downloadUrl

# Upgrade x86
$Object2 = Invoke-RestMethod `
  -Uri 'https://interface.music.163.com/api/pc/upgrade/get' `
  -Method Post `
  -Headers @{ Cookie = 'osver=Microsoft-Windows-10; appver=0.0' } `
  -Body 'action=manual&cpuBitWidth=32&e_r=false'
$Version2 = "$($Object2.data.packageVO.appver).$($Object2.data.packageVO.buildver)"
$InstallerUrl2 = $Object2.data.packageVO.downloadUrl

# Download
$Object3 = Invoke-RestMethod -Uri 'https://music.163.com/api/appcustomconfig/get?key=web-pc-beta-download-links'

$InstallerUrl3 = $Object3.data.'web-pc-beta-download-links'.pcPackage64
$Version3 = [regex]::Match($InstallerUrl3, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

$InstallerUrl4 = $Object3.data.'web-pc-beta-download-links'.pcPackage32
$Version4 = [regex]::Match($InstallerUrl4, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

if ((Compare-Version -ReferenceVersion $Version3 -DifferenceVersion $Version2 ) -ge 0) {
  $Task.Config.Notes = '升级源'

  if ($Version1 -ne $Version2) {
    Write-Host -Object "Task $($Task.Name): The versions are different between the architectures"
    $Task.Config.Notes += '各个架构的版本号不相同'
  } else {
    $Identical = $True
  }

  # Version
  $Task.CurrentState.Version = $Version1

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $InstallerUrl2
  }
  $Task.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $InstallerUrl1
  }

  # ReleaseNotes (zh-CN)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = '"' + $Object1.data.upgradeContent + '"' | ConvertFrom-Json | Format-Text
  }
} else {
  $Task.Config.Notes = '下载源'

  if ($Version3 -ne $Version4) {
    Write-Host -Object "Task $($Task.Name): The versions are different between the architectures"
    $Task.Config.Notes += '各个架构的版本号不相同'
  } else {
    $Identical = $True
  }

  # Version
  $Task.CurrentState.Version = $Version3

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $InstallerUrl4
  }
  $Task.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $InstallerUrl3
  }
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and $Identical }) {
    New-Manifest
  }
}
