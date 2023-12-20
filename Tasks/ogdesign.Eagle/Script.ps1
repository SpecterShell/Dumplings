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
$this.CurrentState.Version = [regex]::Match($InstallerUrl, 'Eagle-([\d\.]+-build\d+)').Groups[1].Value

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = $this.CurrentState.Installer[1]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $Object2 = Invoke-WebRequest -Uri 'https://eagle.cool/' | ConvertFrom-Html

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object2.SelectSingleNode('//*[@id="hero"]/div/div/div/div/div[3]/text()[2]').InnerText,
        '(\d{4}/\d{1,2}/\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
