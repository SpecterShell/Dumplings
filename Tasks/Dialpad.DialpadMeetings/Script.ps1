# x86
$Object1 = Invoke-WebRequest -Uri 'https://storage.googleapis.com/uc_native/stable/win32/ia32/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { $_.Version -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1
# x64
$Object2 = Invoke-WebRequest -Uri 'https://storage.googleapis.com/uc_native/stable/win32/x64/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { $_.Version -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

if ($Object1.Version -ne $Object2.Version) {
  $this.Log("x86 version: $($Object1.Version)")
  $this.Log("x64 version: $($Object2.Version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'exe'
  InstallerUrl  = 'https://storage.googleapis.com/uc_native/stable/win32/ia32/DialpadMeetingsSetup.exe'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'exe'
  InstallerUrl  = 'https://storage.googleapis.com/uc_native/stable/win32/x64/DialpadMeetingsSetup.exe'
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
