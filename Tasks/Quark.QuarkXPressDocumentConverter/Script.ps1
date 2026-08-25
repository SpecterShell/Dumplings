$Match = [regex]::Match($Global:DumplingsStorage.QuarkDownloadPage.Content, '(?s)<h5>QuarkXPress Document Converter\s*</h5>.*?utm_content=qdcv(?<Version>[\d.]+).*?file_url=(?<InstallerUrl>https://files\.quark\.com/Protected/qxp/[^"&\s]+_win\.zip).*?alt="windows"')
if (-not $Match.Success) { throw 'QuarkXPress Document Converter Windows installer link was not found.' }

# Version
$this.CurrentState.Version = $Match.Groups['Version'].Value

# InstallerUrl
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Match.Groups['InstallerUrl'].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'QuarkXPress Document Converter.msi' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'QuarkXPress Document Converter.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
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
