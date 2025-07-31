$Object1 = Invoke-WebRequest -Uri 'https://my.lancom-systems.com/downloads/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.Contains('LANmonitor') -and $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Object1.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('RN') -and $_.href.Contains('LANtools') } catch {} }, 'First')[0].href
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'LANCOM\LANtools\lanmon.cab' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'lanmon.cab'
    $InstallerFile2Extracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFile2Extracted}" $InstallerFile2 'lanmon.exe' | Out-Host
    $InstallerFile3 = Join-Path $InstallerFile2Extracted 'lanmon.exe'
    # RealVersion
    $this.CurrentState.RealVersion = ($InstallerFile3 | Read-FileVersionRawFromExe).ToString()
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
