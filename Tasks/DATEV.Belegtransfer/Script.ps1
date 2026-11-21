$Session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
$null = Invoke-RestMethod -Uri 'https://apps.datev.de/myupdates/api/login/status' -WebSession $Session
$Session.Headers.Add('X-Requested-With', 'dcal')
$Session.Headers.Add('X-XSRF-TOKEN', $Session.Cookies.GetAllCookies().Where({ $_.Name -eq 'XSRF-TOKEN' }, 'First')[0].Value)

$Object2 = Invoke-RestMethod -Uri 'https://apps.datev.de/myupdates/api/amr/download-portal-api/v1/additional-software/ddc1adec-4b1e-4581-b5b0-504fe0d68fd2' -WebSession $Session

# Version
$this.CurrentState.Version = $Object2.version

$Object3 = Invoke-RestMethod -Uri 'https://apps.datev.de/myupdates/api/amr/download-portal-api/v1/download/ddc1adec-4b1e-4581-b5b0-504fe0d68fd2/download-link' -WebSession $Session

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object3.url
}

switch -Regex ($this.Check()) {
  # DATEV's portal version string is not monotonic under WinGet chunk comparison
  # (e.g. "5.5" sorts below "5.49" because chunk 5 < 49), so a genuine update can be
  # classified as "Rollbacked". Treat rollbacks like updates, matching the other DATEV
  # tasks. DATEV does not publish real downgrades on this channel.
  'New|Changed|Updated|Rollbacked' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
