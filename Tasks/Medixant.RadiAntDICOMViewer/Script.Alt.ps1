$Object1 = Invoke-RestMethod -Uri 'https://u2.radiantviewer.com/u/' -Method Post -Body @{
  p = 'x64'
  v = $this.Status.Contains('New') ? '2024.1.0.1600' : $this.LastState.Version
}

if ($Object1.SelectSingleNode('ok')) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.u.v

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..1] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl = "https://www.radiantviewer.com/files/RadiAnt-$($this.CurrentState.RealVersion)-Setup.exe"
  ProductCode  = 'RadiAnt32'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl
  ProductCode  = 'RadiAnt64'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $InstallerUrl
  ProductCode  = 'RadiAnt64ARM'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.radiantviewer.com/products/versions/standard/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//div[contains(@class, 'bl-blogpostheader') and contains(.//div[contains(@class, 'bl-blogposttitle')], '$($this.CurrentState.RealVersion)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('.//div[contains(@class, "bl-blogpostdate")]').InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectNodes('./following-sibling::node()') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
