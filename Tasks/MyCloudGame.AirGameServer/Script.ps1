$Prefix = 'https://www.mycloudgame.com/'

$Object = Invoke-WebRequest -Uri "${Prefix}download.html" | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object.SelectSingleNode('//*[@id="SERVER_VER"]').InnerText,
  '\((.+)\)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object.SelectSingleNode('//*[@id="SERVER_LINK"]').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object.SelectSingleNode('//*[@id="SERVER_LINK2"]').Attributes['href'].Value
}

$ReleaseNotesTitleNode = $Object.SelectNodes("//*[@id='page-top']/table/tbody/tr/td[2]/table/tbody/tr/td/h4[starts-with(./text(), 'AirGame')]") |
  Where-Object -FilterScript { $_.InnerText.EndsWith([regex]::Match($this.CurrentState.Version, '([\d\.]+)').Groups[1].Value) }
if ($ReleaseNotesTitleNode) {
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::ul[1]') | Get-TextContent | Format-Text
  }
} else {
  $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
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
