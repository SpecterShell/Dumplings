$Prefix = 'https://oss-arena.5eplay.com/client/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$((New-Guid).Guid.Split('-')[0])" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'en-US'

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $Object1 = Invoke-RestMethod -Uri 'https://api-client-arena.5eplay.com/api/home'

    try {
      # ReleaseNotes (zh-CN)
      if ($this.CurrentState.Version -eq $Object1.data.login_version_note.version) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object1.data.login_version_note.content.ForEach({ $_.category_name + "`n" + $_.list.ForEach({ $_.title + "`n" + $_.content }) -join "`n" }) -join "`n`n" | Format-Text
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
