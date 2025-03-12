# Global x64
$Object1 = Invoke-RestMethod -Uri 'https://onemark.neux.studio/updates/latest.x64.xml'
# Global x86
$Object2 = Invoke-RestMethod -Uri 'https://onemark.neux.studio/updates/latest.xml'
# China x64
$Object3 = Invoke-RestMethod -Uri 'https://onemark.neuxlab.cn/updates/latest.x64.xml'
# China x86
$Object4 = Invoke-RestMethod -Uri 'https://onemark.neuxlab.cn/updates/latest.xml'

if ((@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property { $_.item.version } -Unique).Count -gt 1) {
  $this.Log("Global x86 version: $($Object2.item.version)")
  $this.Log("Global x64 version: $($Object1.item.version)")
  $this.Log("China x86 version: $($Object4.item.version)")
  $this.Log("China x64 version: $($Object3.item.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.item.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.item.url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.item.url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x86'
  InstallerUrl    = $Object4.item.url
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  Architecture    = 'x64'
  InstallerUrl    = $Object3.item.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrlEN = $Object1.item.changelog
      }
      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrlCN = $Object3.item.changelog
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    try {
      $Object5 = Invoke-WebRequest -Uri $ReleaseNotesUrlEN | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object5.SelectNodes('//*[@id="main"]/div') | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object6 = Invoke-WebRequest -Uri $ReleaseNotesUrlCN | ConvertFrom-Html

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object6.SelectNodes('//*[@id="main"]/div') | Get-TextContent | Format-Text
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
