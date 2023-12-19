$Object = Invoke-RestMethod -Uri 'https://tron-sg.bytelemon.com/api/sdk/check_update?pid=7094553681491663140&uid=1&branch=master&buildId='

# Version
$this.CurrentState.Version = [regex]::Match($Object.data.manifest.win32.version, '(\d+\.\d+\.\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object.data.manifest.win32.extra.installers.ia32
}
if ($Object.data.manifest.win32.extra.installers.ia32 -ne $Object.data.manifest.win32.extra.installers.x64) {
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $Object.data.manifest.win32.extra.installers.x64
  }
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
