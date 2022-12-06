$Object1 = Invoke-RestMethod -Uri 'https://eagle.cool/check-for-update'

# Installer
$InstallerUrl = 'https:' + $Object1.links.windows
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl.Replace('eaglefile.oss-cn-shenzhen.aliyuncs.com', 'r2-app.eagle.cool').Replace('file.eagle.cool', 'r2-app.eagle.cool')
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $InstallerUrl
}

# Version
$Task.CurrentState.Version = [regex]::Match($InstallerUrl, 'Eagle-([\d\.]+-build\d+)').Groups[1].Value

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $InstallerUrl | Read-ProductVersionFromExe

    $Object2 = Invoke-WebRequest -Uri 'https://eagle.cool/' | ConvertFrom-Html

    try {
      # ReleaseTime
      $Task.CurrentState.ReleaseTime = [regex]::Match(
        $Object2.SelectSingleNode('//*[@id="hero"]/div/div/div/div/div[3]/text()[2]').InnerText,
        '(\d{4}/\d{1,2}/\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
