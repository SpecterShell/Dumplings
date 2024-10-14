$Object1 = Invoke-RestMethod -Uri 'https://update.googleapis.com/service/update2' -Method Post -Body @'
<?xml version="1.0" encoding="UTF-8"?>
<request protocol="3.0" ismachine="0">
  <hw sse3="1" />
  <os platform="win" version="10.0.22000" />
  <app appid="{44fc7fe2-65ce-487c-93f4-edee46eeaaab}">
    <updatecheck />
  </app>
</request>
'@

# Version
$this.CurrentState.Version = $Object1.response.app.updatecheck.manifest.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Scope                = 'user'
  InstallerUrl         = ($Object1.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object1.response.app.updatecheck.manifest.packages.package.name
  InstallationMetadata = [ordered]@{
    DefaultInstallLocation = "%LOCALAPPDATA%\Google\GoogleUpdater\$($this.CurrentState.Version)"
    Files                  = @(
      [ordered]@{
        RelativeFilePath = 'updater.exe'
      }
    )
  }
}
$this.CurrentState.Installer += [ordered]@{
  Scope                = 'machine'
  InstallerUrl         = ($Object1.response.app.updatecheck.urls.url.codebase | Select-String -Pattern 'https://dl.google.com' -Raw -SimpleMatch) + $Object1.response.app.updatecheck.manifest.packages.package.name
  InstallationMetadata = [ordered]@{
    DefaultInstallLocation = "%ProgramFiles(x86)%\Google\GoogleUpdater\$($this.CurrentState.Version)"
    Files                  = @(
      [ordered]@{
        RelativeFilePath = 'updater.exe'
      }
    )
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFile2Root = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFile2Root}" $InstallerFile 'updater.7z' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFile2Root 'updater.7z'
    $InstallerFile3Root = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFile3Root}" $InstallerFile2 'bin\updater.exe' | Out-Host
    $InstallerFile3 = Join-Path $InstallerFile3Root 'updater.exe'

    # InstallerSha256 + InstallationMetadata > Files > FileSha256
    $this.CurrentState.Installer.ForEach(
      {
        $_['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
        $_.InstallationMetadata.Files[0]['FileSha256'] = (Get-FileHash -Path $InstallerFile3 -Algorithm SHA256).Hash
      }
    )

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
