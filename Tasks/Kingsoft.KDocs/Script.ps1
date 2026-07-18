$Object1 = (Invoke-RestMethod -Uri 'https://www.kdocs.cn/kdg/api/v1/configure?idList=appOfficial').data.appOfficial | ConvertFrom-Json

# Version
$this.CurrentState.Version = $Object1.kdesktopWinOfficial[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.kdesktopWinOfficial[0].url
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
