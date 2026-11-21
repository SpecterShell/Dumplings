$Prefix = 'https://easymorph.com/download/all-downloads'
$Object1 = Invoke-WebRequest -Uri $Prefix
$Link = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('EasyMorph.') -and $_.href -match 'Setup' } catch {} }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Link.href
}

# Version
$this.CurrentState.Version = [regex]::Match($Link.outerHTML, 'EasyMorph Desktop v(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'EasyMorph.Setup.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'EasyMorph.Setup.exe'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromExe
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      if ($Global:DumplingsStorage.Contains('EasyMorph') -and $Global:DumplingsStorage['EasyMorph'].Contains($this.CurrentState.Version)) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Global:DumplingsStorage['EasyMorph'][$this.CurrentState.Version].ReleaseTime | Get-Date -Format 'yyyy-MM-dd'

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage['EasyMorph'][$this.CurrentState.Version].ReleaseNotes
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
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
