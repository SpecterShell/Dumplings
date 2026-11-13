$Object1 = Invoke-RestMethod -Uri 'https://report2.iciba.com/report/pc/versionUpdate' -Body @{
  version = $this.Status.Contains('New') ? '2022.1.1.0141' : $this.LastState.Version
}

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'inno'
  InstallerUrl  = 'https://download.iciba.com/pc/personal2016/PowerWord.800.12012.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
