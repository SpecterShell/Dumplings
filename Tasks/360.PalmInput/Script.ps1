$Object1 = Invoke-WebRequest -Uri 'https://cdn.soft.360.cn/static/baoku/info_7_0/softinfo_104126128.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectSingleNode('//*[@id="app-data"]/div[3]/div[2]/ul/li[2]/span[2]').InnerText.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="download_btn"]').Attributes['data-downurl'].Value | ConvertTo-Https
}

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="app-data"]/div[3]/div[2]/ul/li[4]/span[2]').InnerText,
  '(\d{4}-\d{1,2}-\d{1,2})'
).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Object1.SelectSingleNode('//*[@id="doc"]/div[3]/div[3]/div[2]/div') | Get-TextContent | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
