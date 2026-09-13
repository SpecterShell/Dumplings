$Object1 = Invoke-WebRequest -Uri 'https://www.proware-cpa.biz/demos/ap/index.html' | ConvertFrom-Html

# ReleaseTime
$this.CurrentState.ReleaseTime = Get-Date -Date "$($Object1.SelectSingleNode('//date-win').InnerText) $($Object1.SelectSingleNode('//date-win-offset').InnerText)" -AsUTC

# Version
$this.CurrentState.Version = $this.CurrentState.ReleaseTime.ToString('yyyy-MM-ddTHH:mm:ssZ')

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://' + $Object1.SelectSingleNode('//url').InnerText + $Object1.SelectSingleNode('//file-win').InnerText
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    $InstallerFile2 = Expand-InnoInstaller -Path $InstallerFile -DestinationPath $InstallerFileExtracted -Name 'ap.exe'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-FileVersionFromExe
    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
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
