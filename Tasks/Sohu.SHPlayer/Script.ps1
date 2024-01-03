$Object1 = Invoke-RestMethod -Uri 'https://p2p.hd.sohu.com.cn/update?clienttype=3&version=7.0.0.0'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.cdn
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://tv.sohu.com/down/index.shtml?downLoad=windows' | Read-ResponseContent -Encoding 'GBK' | ConvertFrom-Html

      if ($Object2.SelectSingleNode('//div[contains(@class, "down_winbox")]/div[2]/div/p/span').InnerText.Contains($this.CurrentState.Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match(
          $Object2.SelectSingleNode('//div[contains(@class, "down_winbox")]/div[2]/div/p/span').InnerText,
          '(\d{4}-\d{1,2}-\d{1,2})'
        ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2.SelectNodes('//div[contains(@class, "down_winbox")]/div[2]/div/div') | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
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
