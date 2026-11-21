# x86
$Object1 = Invoke-RestMethod -Uri 'https://ams.ecosia-browser.net/api/getLatest/0aac13df-2a94-4570-8229-285102897d3d/win/?channelprofilename=PROD&arch=x86'

# x64
$Object2 = Invoke-RestMethod -Uri 'https://ams.ecosia-browser.net/api/getLatest/0aac13df-2a94-4570-8229-285102897d3d/win/?channelprofilename=PROD&arch=x64'

if ($Object1.Version -ne $Object2.Version) {
  $this.Log("x86 version: $($Object1.Version)")
  $this.Log("x64 version: $($Object2.Version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.LocationUri.Replace('//browser.ecosia.org/', '//app-cms-repo.ecosia-browser.net/')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.LocationUri.Replace('//browser.ecosia.org/', '//app-cms-repo.ecosia-browser.net/')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.UpdateDate.ToUniversalTime()
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
