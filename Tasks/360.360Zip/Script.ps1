$Object1 = Invoke-WebRequest -Uri 'https://www.360totalsecurity.com/en/360zip/' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('//*[@id="primary-actions"]/p/span').InnerText,
  '(\d+\.\d+\.\d+\.\d+)'
).Groups[1].Value

$Object2 = Invoke-WebRequest -Uri 'https://www.360totalsecurity.com/en/download-free-360-zip/' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https:' + $Object2.SelectSingleNode('//*[@id="download-intro"]/div[1]/a').Attributes['href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage.Contains('360Zip') -and $Global:DumplingsStorage['360Zip'].Contains($this.CurrentState.Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Global:DumplingsStorage['360Zip'][$this.CurrentState.Version].ReleaseTime

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['360Zip'][$this.CurrentState.Version].ReleaseNotesCN
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
