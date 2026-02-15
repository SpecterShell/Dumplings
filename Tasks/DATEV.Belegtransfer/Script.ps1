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
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
