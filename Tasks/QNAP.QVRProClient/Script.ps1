# x86
# $Object1 = $Global:DumplingsStorage.QNAPApps.docRoot.utility.application.Where({ $_.applicationName -eq 'com.qnap.qvrproclient' }, 'First')[0].platform.Where({ $_.platformName -eq 'WindowsX86' }, 'First')[0].software
# $VersionX86 = "$($Object1.version).$($Object1.buildNumber)"
# x64
$Object2 = $Global:DumplingsStorage.QNAPApps.docRoot.utility.application.Where({ $_.applicationName -eq 'com.qnap.qvrproclient' }, 'First')[0].platform.Where({ $_.platformName -eq 'WindowsX64' }, 'First')[0].software
$VersionX64 = "$($Object2.version).$($Object2.buildNumber)"

# if ($VersionX86 -ne $VersionX64) {
#   $this.Log("x86 version: ${VersionX86}")
#   $this.Log("x64 version: ${VersionX64}")
#   throw 'Inconsistent versions detected'
# }

# Version
$this.CurrentState.Version = $VersionX64

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = $Object1.downloadURL[0]
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.downloadURL[0]
}
# $this.CurrentState.Installer += [ordered]@{
#   InstallerLocale = 'zh-CN'
#   Architecture    = 'x86'
#   InstallerUrl    = $Object1.downloadURL[0].Replace('//download.qnap.com/', '//download.qnap.com.cn/')
# }
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerUrl    = $Object2.downloadURL[0].Replace('//download.qnap.com/', '//download.qnap.com.cn/')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = (Invoke-RestMethod -Uri 'https://www.qnap.com.cn/api/v1/release-notes/utility/QVR%20Pro%20Client?locale=en').result.notes.Windows.Where({ $_.version -eq $Object2.version }, 'First')

      if ($Object3) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object3[0].note | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = (Invoke-RestMethod -Uri 'https://www.qnap.com.cn/api/v1/release-notes/utility/QVR%20Pro%20Client?locale=zh-cn').result.notes.Windows.Where({ $_.version -eq $Object2.version }, 'First')

      if ($Object4 -and $Object4[0].note -ne $Object3[0].note) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object4[0].note | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
