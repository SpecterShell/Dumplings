$Prefix = 'https://www.synaptics.com'

$Object1 = Invoke-WebRequest -Uri 'https://www.synaptics.com/products/displaylink-graphics/downloads/corporate' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//div[@class="latest-official-drivers" and contains(., "Hot Desking")][1]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('./div[@class="left-driver"]').InnerText, 'Release: ([\d\.]+(?: M\d+)?)').Groups[1].Value

$Object3 = Invoke-WebRequest -Uri "${Prefix}$($Object2.SelectSingleNode('.//a[@class="download-link" and contains(text(), "Download MSI")]').Attributes['href'].Value)" | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = ("${Prefix}$($Object3.SelectSingleNode('//a[@download]').Attributes['href'].Value)" | ConvertTo-UnescapedUri).Replace('exe', 'msi').Replace('EXE', 'MSI')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.SelectSingleNode('.//time').Attributes['datetime'].Value | Get-Date -AsUTC

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = "${Prefix}$($Object2.SelectSingleNode('.//a[@class="release-notes-link"]').Attributes['href'].Value)"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'HotDesking - Displaylink\DisplayLink_Win10RS.msi' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'DisplayLink_Win10RS.msi'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      $Object4 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream)

      for ($i = 0; $i -lt 2; $i++) {
        while (-not $Object4.EndOfStream) {
          $String = $Object4.ReadLine()
          if ($String.Contains('C. New Features')) {
            $null = $Object4.ReadLine()
            break
          }
        }
      }
      if (-not $Object4.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object4.EndOfStream) {
          $String = $Object4.ReadLine()
          if ($String -notmatch '^D\. ') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
