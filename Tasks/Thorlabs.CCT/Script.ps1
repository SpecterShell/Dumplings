$Object1 = Invoke-RestMethod -Uri 'https://www.thorlabs.com/software_pages/check_updates.cfm?ItemID=CCT'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = $Object1.ItemID.SoftwarePkg.DownloadLink
}

# Version
$this.CurrentState.Version = [regex]::Matches($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[-1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = Join-Uri $InstallerUrl 'ChangeLog.txt'
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
