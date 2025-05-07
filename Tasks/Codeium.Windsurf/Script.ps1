# User
$Object1 = Invoke-RestMethod -Uri 'https://windsurf-stable.codeium.com/api/update/win32-x64-user/stable'
# Machine
$Object2 = Invoke-RestMethod -Uri 'https://windsurf-stable.codeium.com/api/update/win32-x64/stable'

if ($Object1.productVersion -ne $Object2.productVersion) {
  $this.Log("User version: $($Object1.productVersion)")
  $this.Log("Machine version: $($Object2.productVersion)")
  throw 'Inconsistent versions detected'
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

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.timestamp | ConvertFrom-UnixTimeSeconds
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://codeium.com/changelog' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//main//header[contains(., '$($Object1.windsurfVersion)')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::article') | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
