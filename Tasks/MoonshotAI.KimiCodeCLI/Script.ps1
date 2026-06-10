$Prefix = 'https://code.kimi.com/kimi-code/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}latest" | Read-ResponseContent

# Version
$this.CurrentState.Version = $Object1.Trim()

$Prefix += "binaries/$($this.CurrentState.Version)/"
$Object2 = Invoke-RestMethod -Uri "${Prefix}manifest.json"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object2.platforms.'win32-x64'.filename
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri $Prefix $Object2.platforms.'win32-arm64'.filename
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
