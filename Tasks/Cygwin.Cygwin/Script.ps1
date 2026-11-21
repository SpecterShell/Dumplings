$Object1 = Invoke-RestMethod -Uri 'https://mirrors.kernel.org/sourceware/cygwin/x86_64/setup.ini'

# Version
$this.CurrentState.Version = [regex]::Match($Object1, '(?s)@ cygwin.+?version: (\S+)').Groups[1].Value

$SetupVersion = [regex]::Match($Object1, '(?m)setup-version: (\S+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://cygwin.com/setup/setup-${SetupVersion}.x86.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://cygwin.com/setup/setup-${SetupVersion}.x86_64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  { $_.Contains('Changed') -and -not $_.Contains('Updated') } {
    $this.Config.IgnorePRCheck = $true
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
