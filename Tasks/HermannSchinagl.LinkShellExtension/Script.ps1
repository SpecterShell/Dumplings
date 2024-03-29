$Object1 = Invoke-WebRequest -Uri 'https://schinagl.priv.at/nt/hardlinkshellext/hardlinkshellext.html' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/table/tr[2]/td/div/i').InnerText,
  'Version ([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://schinagl.priv.at/nt/hardlinkshellext/save/$($this.CurrentState.Version.Replace('.', ''))/HardLinkShellExt_win32.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://schinagl.priv.at/nt/hardlinkshellext/save/$($this.CurrentState.Version.Replace('.', ''))/HardLinkShellExt_X64.exe"
}

$ReleaseNotesTitleNode = $Object1.SelectSingleNode("/html/body/table/tr[54]/td[2]/table/tr[contains(./td[2]/text()[1], '$($this.CurrentState.Version)')]")
if ($ReleaseNotesTitleNode) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $ReleaseNotesTitleNode.SelectSingleNode('./td[1]/a').InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesTitleNode.SelectSingleNode('./td[2]/text()[1]/following-sibling::*') | Get-TextContent | Format-Text
  }
} else {
  $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
}

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
