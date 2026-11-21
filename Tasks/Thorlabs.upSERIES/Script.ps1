$Object1 = Invoke-WebRequest -Uri 'https://www.thorlabs.com/api/software_pages/check_updates?ItemID=upSERIES' | Read-ResponseContent | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object1.ItemID.SoftwarePkg.VersionNumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.ItemID.SoftwarePkg.DownloadLink.Replace('\', '/').Replace('//thin01mstroc282prod.dxcloud.episerver.net/', '//media.thorlabs.com/')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.ItemID.SoftwarePkg.ReleaseDate | Get-Date -Format 'yyyy-MM-dd'

      # LicenseUrl (en-US)
      # $this.CurrentState.Locale += [ordered]@{
      #   Locale = 'en-US'
      #   Key    = 'LicenseUrl'
      #   Value  = "https://www.thorlabs.com/software/MUC/upSERIES/upSERIES_V$($this.CurrentState.Version)/License.rtf"
      # }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'upSERIES_Installer.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'upSERIES_Installer.exe'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-FileVersionFromExe
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
