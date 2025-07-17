$Object1 = (Invoke-WebRequest -Uri 'https://vulkan.lunarg.com/sdk/files.json').Content | ConvertFrom-Json -AsHashtable
# x64
$VersionX64 = $Object1.windows.Keys[0]
# arm64
$VersionARM64 = $Object1.warm.Keys[0]

if ($VersionX64 -ne $VersionARM64) {
  $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionARM64}", 'Warning')
  return
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://sdk.lunarg.com/sdk/download/$($this.CurrentState.Version)/windows/$($Object1.windows.Values[0].files.Where({ $_.name -eq 'Runtime' }, 'First')[0].file_name)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://sdk.lunarg.com/sdk/download/$($this.CurrentState.Version)/warm/$($Object1.warm.Values[0].files.Where({ $_.name -eq 'Runtime' }, 'First')[0].file_name)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # LicenseUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'LicenseUrl'
        Value  = "https://vulkan.lunarg.com/software/license/vulkan-$($this.CurrentState.Version)-windows-license-summary.txt"
      }

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = "https://vulkan.lunarg.com/doc/sdk/$($this.CurrentState.Version)/windows/release_notes.html"
      }

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.windows.Values[0].release_date | Get-Date -Format 'yyyy-MM-dd'
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
