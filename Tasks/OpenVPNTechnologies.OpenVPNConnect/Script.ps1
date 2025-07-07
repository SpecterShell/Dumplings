$Object1 = Invoke-WebRequest -Uri "https://packages.openvpn.net/connect/v3/updates/$($this.Status.Contains('New') ? '3.6.0' : $this.LastState.Version)/MSI.txt" -MaximumRetryCount 0 -SkipHttpErrorCheck

if ($Object1.StatusCode -ne 200) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$Object2 = $Object1.Content -replace '(?s)(?<=</SoftwareUpdate>).+' | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object2.SoftwareUpdate.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.SoftwareUpdate.ContentURLx86
}
# x64
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.SoftwareUpdate.ContentURL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = '"' + $Object2.SoftwareUpdate.ReleaseNotes + '"' | ConvertFrom-Json | Format-Text
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
