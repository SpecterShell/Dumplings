$Object1 = (Invoke-RestMethod -Uri 'https://proxyman.io/v1/apps/win/check-update' -Headers @{ 'X-NSProxy-Client' = '11' }).Data.Payload | ConvertFrom-Json

$Prefix = $Object1.feedURL
$this.CurrentState = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | Read-ResponseContent | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'en-US'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesObjects = $Object1.changelog.Where({ $_.build_number -eq $this.CurrentState.Version }, 'First')
      if ($ReleaseNotesObjects) {
        $ReleaseNotes = [System.Collections.Generic.List[string]]::new()
        if ($ReleaseNotesObjects[0].features) {
          $ReleaseNotes.Add("✨ Features`n$($ReleaseNotesObjects[0].features | ConvertTo-UnorderedList)")
        }
        if ($ReleaseNotesObjects[0].improves) {
          $ReleaseNotes.Add("⚡️ Improve`n$($ReleaseNotesObjects[0].improves | ConvertTo-UnorderedList)")
        }
        if ($ReleaseNotesObjects[0].bugs) {
          $ReleaseNotes.Add("🐞 Bugs`n$($ReleaseNotesObjects[0].bugs | ConvertTo-UnorderedList)")
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotes -join "`n`n" | Format-Text
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
