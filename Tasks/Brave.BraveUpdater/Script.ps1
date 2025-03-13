$Object1 = Invoke-RestMethod -Uri 'https://updates.bravesoftware.com/service/update2' -Method Post -Body @"
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0" updaterversion="1.3.361.137" ismachine="0" sessionid="{$((New-Guid).Guid)}" testsource="auto" requestid="{$((New-Guid).Guid)}">
    <os platform="win" version="10" sp="" arch="x64" />
    <app appid="{B131C935-9BE6-41DA-9599-1F776BEB8019}" version="" nextversion="" lang="" brand="" client="">
        <updatecheck />
    </app>
</request>
"@

# Version
$this.CurrentState.Version = $Object1.response.app.updatecheck.manifest.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Scope                = 'user'
  InstallerUrl         = $Object1.response.app.updatecheck.urls.url.codebase + $Object1.response.app.updatecheck.manifest.packages.package.name
  InstallationMetadata = [ordered]@{
    DefaultInstallLocation = "%LOCALAPPDATA%\BraveSoftware\Update\$($this.CurrentState.Version)"
    Files                  = @(
      [ordered]@{
        RelativeFilePath = 'BraveUpdate.exe'
      }
    )
  }
}
$this.CurrentState.Installer += [ordered]@{
  Scope                = 'machine'
  InstallerUrl         = $Object1.response.app.updatecheck.urls.url.codebase + $Object1.response.app.updatecheck.manifest.packages.package.name
  InstallationMetadata = [ordered]@{
    DefaultInstallLocation = "%ProgramFiles(x86)%\BraveSoftware\Update\$($this.CurrentState.Version)"
    Files                  = @(
      [ordered]@{
        RelativeFilePath = 'BraveUpdate.exe'
      }
    )
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    # InstallationMetadata > Files > FileSha256
    Start-ThreadJob -ScriptBlock { Start-Process -FilePath $using:InstallerFile -ArgumentList '/silent', '/install "runtime=true"', '/enterprise' -Wait } | Wait-Job -Timeout 300 | Receive-Job | Out-Host
    $FileSha256 = (Get-FileHash -Path (Join-Path $Env:LOCALAPPDATA 'BraveSoftware' 'Update' $this.CurrentState.Version 'BraveUpdate.exe') -Algorithm SHA256).Hash
    $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallationMetadata.Files[0]['FileSha256'] = $FileSha256 }

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
