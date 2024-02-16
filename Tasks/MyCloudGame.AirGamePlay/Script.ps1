$Prefix = 'https://www.mycloudgame.com/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}download.html" | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="CLIENT_VER"]').InnerText,
  '\((.+)\)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $Object1.SelectSingleNode('//*[@id="WIN_CLIENT_LINK"]').Attributes['href'].Value
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = $Object1.SelectSingleNode('//*[@id="WIN_CLIENT_LINK2"]').Attributes['href'].Value
}

$ReleaseNotesTitleNode = $Object1.SelectSingleNode("//*[@id='page-top']/table/tbody/tr/td[2]/table/tbody/tr/td/h4[starts-with(./text(), 'AirGame')]").Where({ $_.InnerText.EndsWith([regex]::Match($this.CurrentState.Version, '([\d\.]+)').Groups[1].Value) }, 'First')
if ($ReleaseNotesTitleNode) {
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesTitleNode[0].SelectSingleNode('./following-sibling::ul[1]') | Get-TextContent | Format-Text
  }
} else {
  $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
