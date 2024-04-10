$Object1 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0">
  <os platform="win" version="10.0.22000" />
  <app appid="{430FD4D0-B729-4F61-AA34-91526481799D}" version="">
    <updatecheck />
  </app>
</request>
'@

# Version
$this.CurrentState.Version = $Object1.response.app.updatecheck.manifest.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = ($Object1.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object1.response.app.updatecheck.manifest.actions.action.Where({ $_.event -eq 'install' }, 'First')[0].run
  InstallationMetadata = @{
    DefaultInstallLocation = '%LOCALAPPDATA%\Google\Update'
    Files                  = @(
      @{
        RelativeFilePath = ".\$($this.CurrentState.Version)\GoogleUpdate.exe"
      }
    )
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # InstallationMetadata > Files > FileSha256
    Start-ThreadJob -ScriptBlock { Start-Process -FilePath $using:InstallerFile -ArgumentList '/update' -Wait } | Wait-Job -Timeout 300 | Receive-Job | Out-Host
    $this.CurrentState.Installer[0].InstallationMetadata.Files[0]['FileSha256'] = (Join-Path $Env:LOCALAPPDATA 'Google' 'Update' $this.CurrentState.Version 'GoogleUpdate.exe' | Get-FileHash -Algorithm SHA256).Hash

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
