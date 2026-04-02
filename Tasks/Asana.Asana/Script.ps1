# x86
# $Object1 = Invoke-WebRequest -Uri 'https://desktop-downloads.asana.com/win32_ia32/prod/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { [RawVersion]$_.Version } -Bottom 1
# x64
$Object2 = Invoke-WebRequest -Uri 'https://desktop-downloads.asana.com/win32_x64/prod/RELEASES' | Read-ResponseContent | ConvertFrom-SquirrelReleases | Where-Object -FilterScript { -not $_.IsDelta } | Sort-Object -Property { [RawVersion]$_.Version } -Bottom 1

# if ($Object1.Version -ne $Object2.Version) {
#   $this.Log("Inconsistent versions: x86: $($Object1.Version), x64: $($Object2.Version)", 'Error')
#   return
# }

# Version
$this.CurrentState.Version = $Object2.Version

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x86'
#   InstallerUrl = "https://desktop-downloads.asana.com/win32_is32/prod/v$($this.CurrentState.Version)/AsanaSetup.exe"
# }
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://desktop-downloads.asana.com/win32_x64/prod/v$($this.CurrentState.Version)/AsanaSetup.exe"
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
