$Object1 = curl -fsSLA $DumplingsInternetExplorerUserAgent 'https://logtagrecorders.com/software/logtag-xpress/' | Join-String -Separator "`n" | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = curl -fsSLIA $DumplingsInternetExplorerUserAgent -w '%{url_effective}' $Object1.SelectSingleNode('//a[text()="Download"]').Attributes['href'].Value | Select-Object -Last 1
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'LTXpress_(\d+(r\d+)?)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = New-TempFile
    curl -fsSLA $DumplingsInternetExplorerUserAgent -o $InstallerFile $this.CurrentState.Installer[0].InstallerUrl | Out-Host
    # NestedInstallerFiles
    $this.CurrentState.Installer[0]['NestedInstallerFiles'] = @(7z.exe l -ba -slt $InstallerFile '*.exe' | Where-Object -FilterScript { $_ -match '^Path = ' } | ForEach-Object -Process { [ordered]@{ RelativeFilePath = [regex]::Match($_, '^Path = (.+)').Groups[1].Value } } | Select-Object -First 1)
    $InstallerFileExtracted = Expand-TempArchive -Path $InstallerFile -RelativeFilePath $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
    try {
      # RealVersion
      $this.CurrentState.RealVersion = (Get-AdvancedInstallerMsiInfo -Path (Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath)).ProductVersion
    } finally {
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
