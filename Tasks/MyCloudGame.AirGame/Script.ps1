$Prefix = 'https://www.mycloudgame.com/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}download.html" | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="WIN_APP_VER"]').InnerText,
  '\((.+)\)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//*[@id="WIN_APP_LINK2" or @id="WIN_APP_LINK3"]').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
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
