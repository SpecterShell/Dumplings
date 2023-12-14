$Prefix = 'https://www.mycloudgame.com/'

$Object = Invoke-WebRequest -Uri "${Prefix}download.html" | ConvertFrom-Html

# Version
$Task.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('//*[@id="SERVER_VER"]').InnerText,
  '\((.+)\)'
).Groups[1].Value

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object.SelectSingleNode('//*[@id="SERVER_LINK"]').Attributes['href'].Value
}
$Task.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object.SelectSingleNode('//*[@id="SERVER_LINK2"]').Attributes['href'].Value
}

$ReleaseNotesTitleNode = $Object.SelectNodes("//*[@id='page-top']/table/tbody/tr/td[2]/table/tbody/tr/td/h4[starts-with(./text(), 'AirGame')]") |
  Where-Object -FilterScript { $_.InnerText.EndsWith([regex]::Match($Task.CurrentState.Version, '([\d\.]+)').Groups[1].Value) }
if ($ReleaseNotesTitleNode) {
  # ReleaseNotes (zh-CN)
  $Task.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::ul[1]') | Get-TextContent | Format-Text
  }
} else {
  $Task.Logging("No ReleaseNotes for version $($Task.CurrentState.Version)", 'Warning')
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
