$Object1 = Invoke-WebRequest -Uri 'https://www.ugnas.com/download' | ConvertFrom-Html

$Node = $Object1.SelectSingleNode('//div[contains(@class, "type1")]/div[contains(./div[5], "Windows")]')

# Version
$this.CurrentState.Version = [regex]::Match($Node.SelectSingleNode('./div[2]').InnerText, 'V([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Node.SelectSingleNode('./div[8]/a').Attributes['href'].Value.Trim()
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Node.SelectSingleNode('./div[3]').InnerText | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Node.SelectSingleNode('./div[6]/div[2]/div') | Get-TextContent | Format-Text
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
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
