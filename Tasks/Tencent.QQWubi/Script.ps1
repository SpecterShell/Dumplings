$Object1 = Invoke-WebRequest -Uri 'http://qq.pinyin.cn/wubi/' | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="banner_box_wubi"]/div[2]/div[2]/p[1]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri $Object1.SelectSingleNode('//*[@id="banner_box_wubi"]/div[1]/a').Attributes['href'].Value
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="banner_box_wubi"]/div[2]/div[2]/p[2]').InnerText,
  '(\d{4}\.\d{1,2}\.\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = Invoke-RestMethod -Uri 'http://qq.pinyin.cn/js/history_info_wb_pc.js' | Get-EmbeddedJson -StartsFrom 'var pcinfo = ' | ConvertFrom-Json

    try {
      $ReleaseNotes = ($Object2.vHistory | Where-Object -FilterScript { $_.version.Contains($Task.CurrentState.Version) }).version_features | Split-LineEndings
      if ($ReleaseNotes) {
        # ReleaseNotes (zh-CN)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes | Select-Object -Skip 1 | Format-Text
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
