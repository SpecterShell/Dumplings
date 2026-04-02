$Object1 = Invoke-WebRequest -Uri 'https://www.voidtools.com/'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'Download Everything ([\d.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = "https://www.voidtools.com/Everything-$($this.CurrentState.Version).x86.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://www.voidtools.com/Everything-$($this.CurrentState.Version).x64.msi"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'nullsoft'
  InstallerUrl  = "https://www.voidtools.com/Everything-$($this.CurrentState.Version).x86-Setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = "https://www.voidtools.com/Everything-$($this.CurrentState.Version).x64-Setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'arm'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = "https://www.voidtools.com/Everything-$($this.CurrentState.Version).ARM.zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'arm64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = "https://www.voidtools.com/Everything-$($this.CurrentState.Version).ARM64.zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://www.voidtools.com/Changes.txt').RawContentStream)

      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String.Contains($this.CurrentState.Version)) {
          try {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [regex]::Match($String, '(\d{1,2}\W+[a-zA-Z]+\W+\d{4})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
          } catch {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^\S+') {
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
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    } finally {
      ${Object2}?.Dispose()
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
