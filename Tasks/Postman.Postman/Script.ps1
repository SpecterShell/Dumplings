$Object1 = Invoke-RestMethod -Uri 'https://dl.pstmn.io/update/status' -Body @{
  channel        = 'stable'
  currentVersion = $this.Status.Contains('New') ? '10.24.26' : $this.LastState.Version
  platform       = 'windows_64'
} -StatusCodeVariable 'StatusCode'
if ($StatusCode -eq 204) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}
$VersionX64 = $Object1.version

# $Object2 = Invoke-RestMethod -Uri 'https://dl.pstmn.io/update/status' -Body @{
#   channel        = 'stable'
#   currentVersion = $this.Status.Contains('New') ? '10.24.26' : $this.LastState.Version
#   platform       = 'windows_arm64'
# } -StatusCodeVariable 'StatusCode'
# if ($StatusCode -eq 204) {
#   $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
#   return
# }
# $VersionArm64 = $Object2.version

# if ($VersionX64 -ne $VersionArm64) {
#   $this.Log("Inconsistent versions: x64: ${VersionX64}, arm64: ${VersionArm64}", 'Error')
#   return
# }

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.url
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'arm64'
#   InstallerUrl = $Object2.url
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pub_date.ToUniversalTime()

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = ($Object1.notes | ConvertFrom-Json).'Release Notes' | Convert-MarkdownToHtml | Get-TextContent | Format-Text
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
