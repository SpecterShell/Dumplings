$Prefix = 'https://update-nucleus.atlassian.com/Rovo/80c27f7ff6ac3c5d4c1763c75aa54d6b'

$Object1 = (Invoke-RestMethod -Uri "$Prefix/versions.json") | Where-Object -FilterScript { -not $_.dead } | Sort-Object -Property { [version]$_.name } -Bottom 1

# Version
$this.CurrentState.Version = $Object1.name

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "$Prefix/win32/x64/$($Object1.files.Where({ $_.platform -eq 'win32' -and $_.arch -eq 'x64' -and $_.type -eq 'installer' }, 'First')[0].fileName)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "$Prefix/win32/arm64/$($Object1.files.Where({ $_.platform -eq 'win32' -and $_.arch -eq 'arm64' -and $_.type -eq 'installer' }, 'First')[0].fileName)"
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
