$Object1 = Invoke-RestMethod -Uri "https://dm.yealink.com/api/v1/external/usb/access/software/checkVersion?appId=72bbc75337eb4930ad93a5e13e5798d1&systemType=WINDOWS&version=$($this.LastState['Version'] ?? '0.35.63.0')"

if ($Object1.data.needUpdate -eq $false) {
  $this.Log("The last version $($this.LastState['Version']) is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.address
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.data.modifyTime | ConvertFrom-UnixTimeMilliseconds

# ReleaseNotes (en-US)
$this.CurrentState.Locale += [ordered]@{
  Locale = 'en-US'
  Key    = 'ReleaseNotes'
  Value  = $Object1.data.copyWriting.content | Format-Text
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
