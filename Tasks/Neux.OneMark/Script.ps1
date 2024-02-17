# International x64
$Object1 = Invoke-RestMethod -Uri 'https://onemark.neux.studio/updates/latest.x64.xml'
# International x86
$Object2 = Invoke-RestMethod -Uri 'https://onemark.neux.studio/updates/latest.xml'
# Chinese x64
$Object3 = Invoke-RestMethod -Uri 'https://onemark.neuxlab.cn/updates/latest.x64.xml'
# Chinese x86
$Object4 = Invoke-RestMethod -Uri 'https://onemark.neuxlab.cn/updates/latest.xml'

$Identical = $true
if ((@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property { $_.item.version } -Unique).Count -gt 1) {
  $this.Log('Distinct versions detected', 'Warning')
  $Identical = $false
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

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $this.CurrentState.RealVersion = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromMsi

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
