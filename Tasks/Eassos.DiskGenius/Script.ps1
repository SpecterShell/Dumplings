# International
$Object1 = Invoke-RestMethod -Uri 'https://internal.eassos.com/update/diskgenius/update.php' | ConvertFrom-Ini
# Chinese
$Object2 = Invoke-RestMethod -Uri 'https://www.diskgenius.cn/pro/statistics/update.php' | ConvertFrom-Ini

# Version
$Task.CurrentState.Version = $Object1.version.new

# RealVersion
$Task.CurrentState.RealVersion = [regex]::Match($Task.CurrentState.Version, '^(\d+\.\d+\.\d+)').Groups[1].Value

if ($Object1.version.new -ne $Object2.version.new) {
  Write-Host -Object "Task $($Task.Name): The versions are different between the locales"
  $Task.Config.Notes = '各个版本的版本号不相同'
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

switch (Compare-State) {
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
        Write-Host -Object "Task $($Task.Name): No ReleaseTime for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and $Object1.version.new -eq $Object2.version.new }) {
    New-Manifest
  }
}
