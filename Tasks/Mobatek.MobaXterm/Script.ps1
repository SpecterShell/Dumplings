$Object1 = Invoke-WebRequest -Uri 'https://mobaxterm.mobatek.net/download-home-edition.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="off-canvas-wrap"]/div/div/div[2]/section[1]/div[2]/div[2]/a/text()[1]').InnerText,
  'v([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = $Object1.SelectSingleNode('//*[@id="off-canvas-wrap"]/div/div/div[2]/section[1]/div[2]/div[2]/a').Attributes['href'].Value
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "MobaXterm_installer_$($this.CurrentState.Version).msi"
    }
  )
}

$ReleaseNotesTitleNode = $Object1.SelectSingleNode("//div[@class='tight_paragraphe' and contains(./p/text(), '$($this.CurrentState.Version)')]")

# ReleaseTime
$this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.SelectSingleNode('./p').InnerText, '\((\d{4}-\d{1,2}-\d{1,2})\)').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

if ($ReleaseNotesTitleNode) {
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesTitleNode.SelectNodes('./p/following-sibling::node()') | Get-TextContent | Format-Text
  }
} else {
  $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # RealVersion
    $this.CurrentState.RealVersion = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Expand-TempArchive | Join-Path -ChildPath $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Read-ProductVersionFromMsi

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
