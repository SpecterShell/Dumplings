$Object1 = Invoke-RestMethod -Uri 'https://zoom.us/rest/download?os=win'

# Version
$this.CurrentState.Version = $Object1.result.downloadVO.zoomRoomsX64.displayVersion -replace '^(\d+(?:\.\d+)+) \((\d+)\)', '$1.$2'

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'exe'
  InstallerUrl  = "https://cdn.zoom.us/prod/$($this.CurrentState.Version)/x64/zoomrooms-$($this.CurrentState.Version)-x64.exe"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = "https://cdn.zoom.us/prod/$($this.CurrentState.Version)/x64/zoomrooms-$($this.CurrentState.Version)-x64.msi"
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
