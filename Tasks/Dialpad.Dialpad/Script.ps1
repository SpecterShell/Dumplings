$Object1 = Invoke-WebRequest -Uri 'https://storage.googleapis.com/dialpad_native/stable/win32/x64/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { $_.Version -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = "https://storage.googleapis.com/dialpad_native/stable/win32/x64/DialpadSetup-$($this.CurrentState.Version)_x64.exe"
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
