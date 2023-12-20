$Prefix = 'https://download.remnote.io/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object2 = (Invoke-RestMethod -Uri 'https://gateway.hellonext.co/api/v2/changelogs' -Headers @{
        'x-organization' = 'feedback.remnote.com'
      }
    ) | Where-Object -Property title -EQ -Value $this.CurrentState.Version

    try {
      if ($Object2) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2.description_html | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
