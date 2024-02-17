$Object1 = Invoke-RestMethod -Uri 'https://www.terabox.com/api/getsyscfg?clienttype=0&language_type=&cfg_category_keys=[]&version=0'

# Version
$this.CurrentState.Version = $Version = [regex]::Match($Object1.fe_web_guide_setting.cfg_list[0].version, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# RealVersion
$this.CurrentState.RealVersion = [regex]::Match($Object1.fe_web_guide_setting.cfg_list[0].version, '(\d+\.\d+\.\d+)\.\d+').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.fe_web_guide_setting.cfg_list[0].url
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.fe_web_guide_setting.cfg_list[0].update_time | Get-Date -Format 'yyyy-MM-dd'

if ($LocalStorage.Contains('TeraBox') -and $LocalStorage.TeraBox.Contains($Version)) {
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $LocalStorage.TeraBox.$Version.ReleaseNotesEN
  }
} else {
  $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Print()
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
