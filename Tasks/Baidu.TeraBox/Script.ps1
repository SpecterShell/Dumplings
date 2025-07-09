$Object1 = Invoke-RestMethod -Uri 'https://www.terabox.com/api/getsyscfg?clienttype=0&language_type=&cfg_category_keys=[]&version=0'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.fe_web_guide_setting.cfg_list[0].url
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.fe_web_guide_setting.cfg_list[0].update_time | Get-Date -Format 'yyyy-MM-dd'

      if ($Global:DumplingsStorage.Contains('TeraBox') -and $Global:DumplingsStorage.TeraBox.Contains($this.CurrentState.Version)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.TeraBox[$this.CurrentState.Version].ReleaseNotes
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
