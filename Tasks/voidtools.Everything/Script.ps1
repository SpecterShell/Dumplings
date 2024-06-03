$Object1 = Invoke-RestMethod -Uri 'https://www.voidtools.com/everything/update.ini' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Everything[@('major', 'minor', 'revision', 'build')] -join '.'

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

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.Everything.message | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
      if ($Object2.EndOfStream) {
        $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
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
