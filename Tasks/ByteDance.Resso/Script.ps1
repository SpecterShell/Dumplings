$Object1 = Invoke-RestMethod -Uri 'https://tron-sg.bytelemon.com/api/sdk/check_update?pid=7094553681491663140&uid=1&branch=master&buildId='

# Version
$this.CurrentState.Version = $Object1.data.manifest.win32.version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.data.manifest.win32.extra.installers.ia32
}
if ($Object1.data.manifest.win32.extra.installers.ia32 -ne $Object1.data.manifest.win32.extra.installers.x64) {
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $Object1.data.manifest.win32.extra.installers.x64
  }
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
