# International
$Object1 = Invoke-RestMethod -Uri 'https://internal.eassos.com/update/diskgenius/update.php' | ConvertFrom-Ini
# Chinese
$Object2 = Invoke-RestMethod -Uri 'https://www.diskgenius.cn/pro/statistics/update.php' | ConvertFrom-Ini

# Version
$Task.CurrentState.Version = $Object1.version.new

# RealVersion
$Task.CurrentState.RealVersion = [regex]::Match($Task.CurrentState.Version, '^(\d+\.\d+\.\d+)').Groups[1].Value

if ($Object1.version.new -ne $Object2.version.new) {
  $Task.Logging('Distinct versions detected', 'Warning')
  $Task.Config.Notes = '检测到不同的版本'
}

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://engdownload.eassos.cn/DGEngSetup$($Object1.version.new.Replace('.','')).exe"
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = "https://download.eassos.cn/DGSetup$($Object2.version.new.Replace('.','')).exe"
}

# ReleaseNotes (en-US)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1[$Object1.version.new].releasenote.Split('`|') | Format-Text
}

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object2[$Object2.version.new].releasenote.Split('`|') | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Object3 = Invoke-WebRequest -Uri 'https://www.diskgenius.com/' | ConvertFrom-Html
    $Object4 = Invoke-WebRequest -Uri 'https://www.diskgenius.cn/download.php' | ConvertFrom-Html

    try {
      if ($Object3.SelectSingleNode('/html/body/div[6]/div[1]/div/div/div[2]/div[1]/span[1]').InnerText.Contains($Task.CurrentState.Version)) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match(
          $Object3.SelectSingleNode('/html/body/div[6]/div[1]/div/div/div[2]/div[1]/span[3]').InnerText,
          'Updated:\s*(.+)'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
      } elseif ($Object4.SelectSingleNode('/html/body/div[3]/div/div[4]/h4/text()').InnerText.Contains($Task.CurrentState.Version)) {
        # ReleaseTime
        $Task.CurrentState.ReleaseTime = [regex]::Match(
          $Object4.SelectSingleNode('/html/body/div[3]/div/div[3]/p').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
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
  ({ $_ -ge 3 -and $Object1.version.new -eq $Object2.version.new }) {
    $Task.Submit()
  }
}
