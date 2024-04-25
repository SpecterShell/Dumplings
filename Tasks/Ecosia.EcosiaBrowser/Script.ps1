# x64
$Object1 = Invoke-RestMethod -Uri 'https://ams.ecosia-browser.net/api/getLatest/0aac13df-2a94-4570-8229-285102897d3d/win/?channelprofilename=PROD&arch=x64'
$Version1 = $Object1.Version

# x86
$Object2 = Invoke-RestMethod -Uri 'https://ams.ecosia-browser.net/api/getLatest/0aac13df-2a94-4570-8229-285102897d3d/win/?channelprofilename=PROD&arch=x86'
$Version2 = $Object2.Version

if ($Version1 -ne $Version2) { throw 'Distinct versions detected' }

# Version
$this.CurrentState.Version = $Version1

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.LocationUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.LocationUri
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.UpdateDate.ToUniversalTime()

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
