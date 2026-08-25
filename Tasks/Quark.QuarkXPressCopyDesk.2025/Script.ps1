$Match = [regex]::Match($Global:DumplingsStorage.QuarkDownloadPage.Content, '(?s)<h5>QuarkXPress CopyDesk 2025\s*</h5>.*?utm_content=qcd2025v(?<Version>[\d.]+).*?file_url=\s*(?<InstallerUrl>https://files\.quark\.com/Protected/qxp/[^"&\s]+_Win\.zip).*?alt="windows"')
if (-not $Match.Success) { throw 'QuarkXPress CopyDesk 2025 Windows installer link was not found.' }

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
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'QuarkXPress CopyDesk 2025.msi' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'QuarkXPress CopyDesk 2025.msi'
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
