$Object1 = Invoke-RestMethod -Uri 'http://www.fancynode.com.cn:8080/FancyApplicationService/update/pxcook/update_cooperation.do'

# Version
$this.CurrentState.Version = $Object1.config.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.config.downloadWin32
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.config.downloadWin64
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.config.date | Get-Date | ConvertTo-UtcDateTime -Id 'China Standard Time'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://fancynode.com.cn/pxcook/version' | ConvertFrom-Html

      if ($Object2.SelectSingleNode('//*[@id="version-list1"]/div[1]/p').InnerText -cmatch '([\d\.]+)' -and $this.CurrentState.Version.Contains($Matches[1])) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('//*[@id="version-list1"]/*[self::div[@class="item"] or self::ul]//*[self::p or self::li]') |
            ForEach-Object -Process { ($_.Name -eq 'li' ? '- ' : "`n") + $_.InnerText } |
            Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
