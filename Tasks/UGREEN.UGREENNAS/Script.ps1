$Object = Invoke-WebRequest -Uri 'https://www.ugnas.com/download' | ConvertFrom-Html

$Node = $Object.SelectSingleNode('//div[contains(@class, "type1")]/div[contains(./div[5], "Windows")]')

# Version
$Task.CurrentState.Version = [regex]::Match($Node.SelectSingleNode('./div[2]').InnerText, 'V([\d\.]+)').Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Node.SelectSingleNode('./div[8]/a').Attributes['href'].Value.Trim()
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $Node.SelectSingleNode('./div[3]').InnerText | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotes (zh-CN)
$Task.CurrentState.Locale += [ordered]@{
  Locale = 'zh-CN'
  Key    = 'ReleaseNotes'
  Value  = $Node.SelectSingleNode('./div[6]/div[2]/div') | Get-TextContent | Format-Text
}

switch ($Task.Check()) {
  ({ $_ -ge 1 }) {
    $Task.Write()
  }
  ({ $_ -ge 2 }) {
    $Task.Message()
  }
  ({ $_ -ge 3 }) {
    $Task.Submit()
  }
}
