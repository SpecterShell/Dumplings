$InstallerUrl = Get-RedirectedUrl1st -Uri 'https://www.adobe.com/go/Connect11msi' -Method GET

# Version
$this.CurrentState.Version = [regex]::Match($InstallerUrl, '(20\d+(_\d+)+)').Groups[1].Value.Replace('_', '.') -replace '^20'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msi'
  InstallerUrl  = $InstallerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if ($Global:DumplingsStorage.Contains('AdobeConnect') -and $Global:DumplingsStorage.AdobeConnect.Contains($this.CurrentState.Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Global:DumplingsStorage.AdobeConnect[$this.CurrentState.Version].ReleaseTime | Get-Date -AsUTC
      } else {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
