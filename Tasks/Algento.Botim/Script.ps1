# Should be a POST request, but use GET for convenience
$Object1 = Invoke-RestMethod -Uri 'https://web.botim.me/user/signup2/checkversion.json' -Headers @{ 'AES-HASH' = 'xxxxx' } -Body @{
  data = @{
    'devicetype' = 4
    'version'    = $this.LastState.Contains('Version') ? $this.LastState.Version : '1.7.4'
  } | ConvertTo-Json -Compress
} -ContentType 'application/json'
$Object2 = $Object1.data | ConvertFrom-Json

if ($Object2.upgradetype -eq 0) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$Object3 = Invoke-RestMethod -Uri $Object2.desktopupgradeymlurl | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object3.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Object2.desktopupgradeymlurl $Object3.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.releaseDate | Get-Date -AsUTC

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.upgradeinfo | Format-Text
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
