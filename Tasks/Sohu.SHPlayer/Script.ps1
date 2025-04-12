$Object1 = Invoke-WebRequest -Uri 'https://tv.sohu.com/down/index.shtml?downLoad=windows' | Read-ResponseContent -Encoding 'GBK' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrls -Uri "https:$($Object1.SelectSingleNode('//div[contains(@class, "down_winbox")]/div[2]/a').Attributes['href'].Value)" -Method GET | Select-Object -Index 1
}

# Version
$this.CurrentState.Version = [regex]::Match(
  $this.CurrentState.Installer[0].InstallerUrl,
  '(\d+(?:\.\d+){3,})'
).Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $Object1.SelectSingleNode('//div[contains(@class, "down_winbox")]/div[2]/div/p/span').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.SelectNodes('//div[contains(@class, "down_winbox")]/div[2]/div/div') | Get-TextContent | Format-Text
      }
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
