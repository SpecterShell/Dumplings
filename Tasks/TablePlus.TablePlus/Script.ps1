# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl1st -Uri 'https://tableplus.com/release/windows/tableplus_latest'
}

# Version
$this.CurrentState.Version = $Version = [regex]::Match($InstallerUrl, '/(\d+\.\d+\.\d+)/').Groups[1].Value

if ($Global:DumplingsStorage['TablePlus'].Contains($Version)) {
  # ReleaseTime
  $this.CurrentState.ReleaseTime = $Global:DumplingsStorage['TablePlus'].$Version.ReleaseTime

  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $Global:DumplingsStorage['TablePlus'].$Version.ReleaseNotes
  }
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
