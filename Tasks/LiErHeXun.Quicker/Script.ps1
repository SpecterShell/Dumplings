# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://getquicker.net/download/item/fast_x86'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $InstallerUrl = Get-RedirectedUrl -Uri 'https://getquicker.net/download/item/fast_x64'
}

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '\.(\d+\.\d+\.\d+\.\d+)\.').Groups[1].Value

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object3 = Invoke-WebRequest -Uri 'https://getquicker.net/changelog?type=Pc&fromQuicker=true' | ConvertFrom-Html

      $ReleaseNotesNode = $Object3.SelectSingleNode("//*[@id='body']/div/div/div[1]/div/div[contains(./div[1]/div/h1, '$([regex]::Match($this.CurrentState.Version, '(\d+\.\d+\.\d+)').Groups[1].Value)')]")
      if ($ReleaseNotesNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $ReleaseNotesNode.SelectSingleNode('./div[1]/div/span').InnerText | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.SelectSingleNode('./div[2]/div') | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
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
