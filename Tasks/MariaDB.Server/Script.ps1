$Object1 = Invoke-RestMethod -Uri 'https://downloads.mariadb.org/rest-api/mariadb/all-releases/'

# Version
$this.CurrentState.Version = $Version = $Object1.releases.Where({ $_.status -eq 'stable' }, 'First')[0].release_number

$Object2 = (Invoke-RestMethod -Uri "https://downloads.mariadb.org/rest-api/mariadb/${Version}/?os=Windows&cpu=x86_64").release_data.$Version
# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.files.Where({ $_.package_type -eq 'MSI Package' }, 'First')[0].file_download_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.date_of_release | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

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
