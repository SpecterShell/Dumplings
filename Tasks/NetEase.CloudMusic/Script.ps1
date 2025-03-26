# x86
$Object1 = Invoke-RestMethod `
  -Uri 'https://interface.music.163.com/api/pc/upgrade/get' `
  -Method Post `
  -Headers @{ Cookie = "osver=Microsoft-Windows-10; appver=$($this.LastState.Version ?? '3.0.6.202423'); MUSIC_A=15e860272ed0803ccf979188982b610ab086a424d18df0f04ee8b1d194962355ef2ae33b30bb5917c514d981210de4857a446f6ceddb779fec58efb075f2174dcb7ce23cca3bd6be03a4f1d7e1fccdebb72149bd3b14523943124f3fcebe94e446b14e3f0c3f8af94212382188fe1965" } `
  -Body 'action=manual&cpuBitWidth=32&e_r=false'
$VersionX86 = "$($Object1.data.packageVO.appver).$($Object1.data.packageVO.buildver)"

# x64
$Object2 = Invoke-RestMethod `
  -Uri 'https://interface.music.163.com/api/pc/upgrade/get' `
  -Method Post `
  -Headers @{ Cookie = "osver=Microsoft-Windows-10; appver=$($this.LastState.Version ?? '3.0.6.202423'); MUSIC_A=15e860272ed0803ccf979188982b610ab086a424d18df0f04ee8b1d194962355ef2ae33b30bb5917c514d981210de4857a446f6ceddb779fec58efb075f2174dcb7ce23cca3bd6be03a4f1d7e1fccdebb72149bd3b14523943124f3fcebe94e446b14e3f0c3f8af94212382188fe1965" } `
  -Body 'action=manual&cpuBitWidth=64&e_r=false'
$VersionX64 = "$($Object2.data.packageVO.appver).$($Object2.data.packageVO.buildver)"

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.packageVO.downloadUrl
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.data.packageVO.downloadUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = '"' + $Object2.data.upgradeContent + '"' | ConvertFrom-Json | Format-Text
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
