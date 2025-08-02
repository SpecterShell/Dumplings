$Object1 = Invoke-RestMethod -Uri 'https://updates-api.picotech.com/api/v3/Releases/Picoscope/TAndM?Os=Windows&Architecture=AMD64&EnableBetaVersions=False&GetLatestVersion=True'

# Version
$this.CurrentState.Version = $Object1[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1[0].releaseDate.ToUniversalTime()


      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = @"
New features
$($Object1[0].newFeatures | ConvertTo-UnorderedList)

Bug fixes
$($Object1[0].bugFixes | ConvertTo-UnorderedList)
"@ | Format-Text
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
