# Upgrade source
$Object1 = Invoke-CloudMusicApi `
  -Path '/pc/upgrade/get' `
  -Params @{ 'e_r' = $false; 'action' = 'manual' } `
  -Cookies @{ osver = 'Microsoft-Windows-10'; appver = '0.0' }
$Version1 = "$($Object1.data.packageVO.appver).$($Object1.data.packageVO.buildver)"

# Download source
$InstallerUrl2 = Get-RedirectedUrl -Uri 'https://music.163.com/api/pc/package/download/latest'
$Version2 = [regex]::Match($InstallerUrl2, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

if ((Compare-Version -ReferenceVersion $Version2 -DifferenceVersion $Version1 ) -ge 0) {
  $Task.Config.Notes = '升级源'

  # Version
  $Task.CurrentState.Version = $Version1

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = $Object1.data.packageVO.downloadUrl
  }

  # ReleaseNotes (zh-CN)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = '"' + $Object1.data.upgradeContent + '"' | ConvertFrom-Json | Format-Text
  }
} else {
  $Task.Config.Notes = '下载源'

  # Version
  $Task.CurrentState.Version = $Version2

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    InstallerUrl = $InstallerUrl2
  }
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
