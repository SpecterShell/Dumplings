# x64 User
$Object1 = Invoke-RestMethod -Uri "https://windsurf-stable.codeium.com/api/update/win32-x64-user/stable?v=$($this.Status.Contains('New') ? '3.0.12' : $this.LastState.Version)"
# x64 Machine
$Object2 = Invoke-RestMethod -Uri "https://windsurf-stable.codeium.com/api/update/win32-x64/stable?v=$($this.Status.Contains('New') ? '3.0.12' : $this.LastState.Version)"
# arm64 User
$Object3 = Invoke-RestMethod -Uri "https://windsurf-stable.codeium.com/api/update/win32-arm64-user/stable?v=$($this.Status.Contains('New') ? '3.0.12' : $this.LastState.Version)"
# arm64 Machine
$Object4 = Invoke-RestMethod -Uri "https://windsurf-stable.codeium.com/api/update/win32-arm64/stable?v=$($this.Status.Contains('New') ? '3.0.12' : $this.LastState.Version)"

if (@(@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property { $_.productVersion } -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x64 user: $($Object1.productVersion), x64 machine: $($Object2.productVersion), arm64 user: $($Object3.productVersion), arm64 machine: $($Object4.productVersion)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.windsurfVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  Scope           = 'user'
  InstallerUrl    = $Object1.url
  InstallerSha256 = $Object1.sha256hash.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'x64'
  Scope           = 'machine'
  InstallerUrl    = $Object2.url
  InstallerSha256 = $Object2.sha256hash.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  Scope           = 'user'
  InstallerUrl    = $Object3.url
  InstallerSha256 = $Object3.sha256hash.ToUpper()
}
$this.CurrentState.Installer += [ordered]@{
  Architecture    = 'arm64'
  Scope           = 'machine'
  InstallerUrl    = $Object4.url
  InstallerSha256 = $Object4.sha256hash.ToUpper()
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.timestamp | ConvertFrom-UnixTimeMilliseconds
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://docs.devin.ai/desktop/changelog' | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//div[contains(@id, '$($this.CurrentState.Version.Replace('.', '-'))')]")
      if ($ReleaseNotesNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div[last()]') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
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
