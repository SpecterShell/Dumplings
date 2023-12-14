# x86
$Object1 = Invoke-RestMethod -Uri 'https://aec.pcw365.com/forceupdatenew.php?type=view&bit=0'
# x64
$Object2 = Invoke-RestMethod -Uri 'https://aec.pcw365.com/forceupdatenew.php?type=view&bit=1'

# Version
$Task.CurrentState.Version = $Object2.root.curversionnow_name

if ($Object1.root.curversionnow_name -ne $Object2.root.curversionnow_name) {
  $Task.Logging('Distinct versions detected', 'Warning')
  $Task.Config.Notes = '检测到不同的版本'
}

# Installer
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.root.updateExeUrl
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.root.updateExeUrl
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object2.root.description.'#text' | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[1].InstallerUrl | Read-ProductVersionFromExe

    $Object3 = Invoke-WebRequest -Uri 'https://www.olcad.com/mini_view.html' | ConvertFrom-Html

    try {
      if ($Object3.SelectSingleNode('//*[@id="detail01"]/ul/li[5]').InnerText.Contains($Task.CurrentState.Version)) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match(
          $Object3.SelectSingleNode('//*[@id="detail01"]/ul/li[3]').InnerText.Trim(),
          '(\d{4}年\d{1,2}月\d{1,2}日)'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
      } else {
        $Task.Logging("No ReleaseTime for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 -and $Object1.root.curversionnow_name -eq $Object2.root.curversionnow_name }) {
    $Task.Submit()
  }
}
