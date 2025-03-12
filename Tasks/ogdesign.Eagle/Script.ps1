$Object1 = Invoke-RestMethod -Uri 'https://eagle.cool/check-for-update'

# Installer
$InstallerUrl = 'https:' + $Object1.links.windows
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = $InstallerUrl.Replace('eaglefile.oss-cn-shenzhen.aliyuncs.com', 'r2-app.eagle.cool').Replace('file.eagle.cool', 'r2-app.eagle.cool')
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $InstallerUrl
}

# Version
$VersionMatches = [regex]::Match($InstallerUrl, 'Eagle-([\d\.]+).*(build\d+)')
$this.CurrentState.Version = "$($VersionMatches.Groups[1].Value)-$($VersionMatches.Groups[2].Value)"

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $WinGetInstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://eagle.cool/' | ConvertFrom-Html

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object2.SelectSingleNode('//*[@id="hero"]/div/div/div/div/div[3]/text()[2]').InnerText,
        '(\d{4}/\d{1,2}/\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
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
