$Response = Invoke-RestMethod -Uri 'https://www.jianguoyun.com/static/exe/latestVersion'
# x86 + x64
$Object1 = $Response | Where-Object -Property 'OS' -EQ -Value 'win-wpf-client'
# arm64
$Object2 = $Response | Where-Object -Property 'OS' -EQ -Value 'win-wpf-client-arm64'

# Version
$Task.CurrentState.Version = $Object1.exVer

if ($Object1.exVer -ne $Object2.exVer) {
  $Task.Logging('Distinct versions detected', 'Warning')
}

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://pkg-cdn.jianguoyun.com/static/exe/installer/$($Task.CurrentState.Version)/NutstoreWindowsWPF_Full_$($Task.CurrentState.Version).exe"
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://pkg-cdn.jianguoyun.com/static/exe/installer/$($Task.CurrentState.Version)/NutstoreWindowsWPF_Full_$($Task.CurrentState.Version).exe"
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://pkg-cdn.jianguoyun.com/static/exe/installer/$($Task.CurrentState.Version)/NutstoreWindowsWPF_Full_$($Task.CurrentState.Version)_ARM64.exe"
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object3 = Invoke-WebRequest -Uri 'https://help.jianguoyun.com/?p=1415' | ConvertFrom-Html

    try {
      $ReleaseNotesNode = $Object3.SelectSingleNode("//*[@id='post-1415']/div/p[contains(./strong/text(), '$($Task.CurrentState.Version)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match(
          $ReleaseNotesNode.SelectSingleNode('./strong').InnerText,
          '(\d{4}年\d{1,2}月\d{1,2}日)'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./following-sibling::ol[1]') | Get-TextContent | Format-Text
        }
      } else {
        $Task.Logging("No ReleaseTime and ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 -and $Object1.exVer -eq $Object2.exVer }) {
    $Task.Submit()
  }
}
