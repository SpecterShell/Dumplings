$Prefix = 'https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}stable"

# Version
$this.CurrentState.Version = $Object1.Content.Trim()

$Object2 = Invoke-RestMethod -Uri "${Prefix}$($this.CurrentState.Version)/manifest.json"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  InstallerUrl    = "${Prefix}$($this.CurrentState.Version)/win32-x64/claude.exe"
  InstallerSha256 = $Object2.platforms.'win32-x64'.checksum.ToUpper()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.buildDate.ToUniversalTime()
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
