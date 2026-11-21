$Object1 = Invoke-RestMethod -Uri 'https://zoom.us/rest/download?os=win'

$VersionMatches = [regex]::Match($Object1.result.downloadVO.zoomRC.displayVersion, '((\d+\.\d+)\.\d+) \((\d+)\)')

# Version
$this.CurrentState.Version = "$($VersionMatches.Groups[1].Value).$($VersionMatches.Groups[3].Value)"

# RealVersion
$this.CurrentState.RealVersion = "$($VersionMatches.Groups[2].Value).$($VersionMatches.Groups[3].Value)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://zoom.us/client/$($this.CurrentState.Version)/$($Object1.result.downloadVO.zoomRC.packageName)"
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
