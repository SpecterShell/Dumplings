$Response = Invoke-RestMethod -Uri 'https://www.jianguoyun.com/static/exe/latestVersion'
# x86 + x64
$Object1 = $Response.Where({ $_.OS -eq 'win-wpf-client' }, 'First')[0]
# arm64
$Object2 = $Response.Where({ $_.OS -eq 'win-wpf-client-arm64' }, 'First')[0]

if ($Object1.exVer -ne $Object2.exVer) {
  $this.Log("x86 + x64 version: $($Object1.exVer)")
  $this.Log("arm64 version: $($Object2.exVer)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object1.exVer

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://pkg-cdn.jianguoyun.com/static/exe/installer/$($this.CurrentState.Version)/NutstoreWindowsWPF_Full_$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://pkg-cdn.jianguoyun.com/static/exe/installer/$($this.CurrentState.Version)/NutstoreWindowsWPF_Full_$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://pkg-cdn.jianguoyun.com/static/exe/installer/$($this.CurrentState.Version)/NutstoreWindowsWPF_Full_$($this.CurrentState.Version)_ARM64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object3 = Invoke-WebRequest -Uri 'https://help.jianguoyun.com/?p=1415' | ConvertFrom-Html

      $ReleaseNotesNode = $Object3.SelectSingleNode("//*[@id='post-1415']/div/p[contains(./strong/text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode.SelectSingleNode('./strong').InnerText,
          '(\d{4}年\d{1,2}月\d{1,2}日)'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./following-sibling::ol[1]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
