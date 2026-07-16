$Object1 = Invoke-RestMethod -Uri 'http://www.xploview.com/Cygnus/Proxy' -Method Post -Body @{
  type          = 'text'
  action        = 'get'
  widgetId      = 'SS41499unjWoLeSLb'
  userId        = '0'
  applicationId = 'SS'
}
$Object2 = $Object1.initData.configData.Content | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.Where({ try { $_.outerHTML.Contains('Windows') -and -not $_.outerHTML.Contains('Legacy') } catch {} }, 'First')[0].href | ConvertTo-HtmlDecodedText
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {

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
