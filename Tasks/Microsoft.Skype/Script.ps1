$Object1 = Invoke-RestMethod -Uri "https://get.skype.com/s4l-update?version=$($this.LastState.Contains('Version') ? $this.LastState.Version : '8.112.0.203')&os=win&ring=production&app=s4l" -StatusCodeVariable 'StatusCode'

if ($StatusCode -eq 204) {
  $this.Log("The last version $($this.LastState.Version) is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1.name, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..1] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.pub_date.ToUniversalTime()

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
