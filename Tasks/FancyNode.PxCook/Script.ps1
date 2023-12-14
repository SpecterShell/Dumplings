$Object1 = Invoke-RestMethod -Uri 'http://www.fancynode.com.cn:8080/FancyApplicationService/update/pxcook/update_cooperation.do'

# Version
$Task.CurrentState.Version = $Object1.config.version

# Installer
$InstallerUrl = $Object1.config.downloadWin64
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.config.downloadWin32
}
$Task.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.config.downloadWin64
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Object1.config.date | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $InstallerUrl | Read-ProductVersionFromExe

    $Object2 = Invoke-WebRequest -Uri 'https://fancynode.com.cn/pxcook/version' | ConvertFrom-Html
    try {
      # ReleaseNotes (zh-CN)
      if ($Object2.SelectSingleNode('//*[@id="version-list1"]/div[1]/p').InnerText -cmatch '([\d\.]+)' -and $Task.CurrentState.Version.Contains($Matches[1])) {
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('//*[@id="version-list1"]/*[self::div[@class="item"] or self::ul]//*[self::p or self::li]') |
            ForEach-Object -Process { ($_.Name -eq 'li' ? '- ' : "`n") + $_.InnerText } |
            Format-Text
        }
      } else {
        $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
      }
    } catch {
      $Task.Logging($_, 'Warning')
    }

    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
