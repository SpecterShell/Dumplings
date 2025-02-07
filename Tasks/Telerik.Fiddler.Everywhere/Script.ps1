$Prefix = 'https://downloads.getfiddler.com/win/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'en-US'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/telerik/fiddler-everywhere-docs/master/release-notes/release-notes.json').Where({ $_.version -eq $this.CurrentState.Version })

      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= $Object2[0].date | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].items | ForEach-Object -Process { "$($_.type)`n$($_.entries.title | ConvertTo-UnorderedList)" } | Join-String -Separator "`n`n" | Format-Text
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
