# There are two kinds of versions: version and version_code
# A type transform error will occur if version_code is not present and the version contains numbers >= 10
$Object1 = Invoke-RestMethod -Uri "https://rest.enpass.io/enpass/alert/?package=in.sinew.enpass.win&version=$($this.LastState.Contains('VersionParts') ? $this.LastState.VersionParts[0] : '6.9.5')&version_code=$($this.LastState.Contains('VersionParts') ? $this.LastState.VersionParts[1] : '1639')&language=en|us"

if (-not $Object1.update) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = "$($Object1.version).$($Object1.version_code)"

# For filling in the URL queries
$this.CurrentState.VersionParts = @($Object1.version, $Object1.version_code)

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.release_note | ConvertFrom-Html | Get-TextContent | Format-Text
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
