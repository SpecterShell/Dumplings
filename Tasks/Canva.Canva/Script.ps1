$Prefix = 'https://desktop-release.canva.com/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = Join-Uri $Prefix $Object1.files[0].url
  InstallationMetadata = [ordered]@{
    DefaultInstallLocation = '%LOCALAPPDATA%\Programs\Canva'
    Files                  = @(
      [ordered]@{
        RelativeFilePath = 'Canva.exe'
        FileType         = 'launch'
      }
    )
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile '$PLUGINSDIR\app-64.7z' | Out-Host

    $InstallerFile2 = Join-Path $InstallerFileExtracted 'app-64.7z'
    $InstallerFile2Extracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFile2Extracted}" $InstallerFile2 'Canva.exe' | Out-Host
    $InstallerFile3 = Join-Path $InstallerFile2Extracted 'Canva.exe'
    # InstallationMetadata > Files > FileSha256
    $this.CurrentState.Installer[0].InstallationMetadata.Files[0]['FileSha256'] = (Get-FileHash -Path $InstallerFile3 -Algorithm SHA256).Hash
    Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
