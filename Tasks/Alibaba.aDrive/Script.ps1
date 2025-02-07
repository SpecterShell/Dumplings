$Object1 = Invoke-RestMethod -Uri 'https://www.aliyundrive.com/desktop/version/update.json'

$this.CurrentState = Invoke-RestMethod -Uri "$($Object1.url)/win32/x64/latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Locale 'zh-CN'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-WebRequest -Uri "$($Object1.url)/updateLog.json").Content | ConvertFrom-Json -AsHashtable

      if ($Object2.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object2[$this.CurrentState.Version].logs | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
