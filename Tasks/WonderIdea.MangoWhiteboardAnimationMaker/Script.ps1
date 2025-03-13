$Object1 = Invoke-WebRequest -Uri 'https://mangoanimate.com/clientapi/update' -Headers @{
  'Referer'    = 'app:/HandActionPlayer.swf'
  'User-Agent' = 'AdobeAIR/29.0'
} -Body @{
  version = $this.Status.Contains('New') ? $this.LastState.Version : '2.1.800'
  os      = 'Windows 10'
  bit     = '64'
} | Select-Object -ExpandProperty 'Content' | ConvertFrom-Json -AsHashtable

if ($Object1.Size -eq 0) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.CurrentVersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.FileURL | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object1.DescriptionURL | ConvertTo-Https
      }

      $Object3 = Invoke-RestMethod -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object3.SelectNodes('//ul[@class="productFeatures"]/li/node()') | Get-TextContent | Format-Text
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
