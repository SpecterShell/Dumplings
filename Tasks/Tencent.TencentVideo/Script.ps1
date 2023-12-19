$Object = Invoke-WebRequest -Uri 'https://v.qq.com/download.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('//*[@id="mod_container"]/div[2]/div[1]/div[1]/div/span[1]').InnerText,
  'V([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object.SelectSingleNode('//*[@id="mod_container"]/div[2]/div[1]/div[1]/a').Attributes['href'].Value.Replace('dldir1.qq.com', 'dldir1v6.qq.com')
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match(
  $Object.SelectSingleNode('//*[@id="mod_container"]/div[2]/div[1]/div[1]/div/span[3]').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object.SelectSingleNode('//*[@id="mod_container"]/div[2]/div[1]/div[1]/div/span[4]/div/ul') | Get-TextContent | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
