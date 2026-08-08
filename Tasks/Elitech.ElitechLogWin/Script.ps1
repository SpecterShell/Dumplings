$Object1 = Invoke-WebRequest -Uri 'https://www.elitechus.com/pages/softwares' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[contains(./h3, "ElitechLog(Win)")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('./h3').InnerText, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.Attributes['data-href'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage.Contains('ElitechLogWin') -and $Global:DumplingsStorage['ElitechLogWin'].Contains($this.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['ElitechLogWin'][$this.CurrentState.Version].ReleaseNotesEN
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['ElitechLogWin'][$this.CurrentState.Version].ReleaseNotesCN
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
