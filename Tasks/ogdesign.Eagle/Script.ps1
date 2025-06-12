$Object1 = Invoke-RestMethod -Uri 'https://core.eagle.cool/check-for-update'

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
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.publishedDate.ToUniversalTime()
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
