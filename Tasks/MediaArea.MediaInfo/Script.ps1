$Object1 = Invoke-WebRequest -Uri 'https://mediaarea.net/en/MediaInfo/Download/Windows' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectSingleNode('//table[contains(@class, "download")]/tbody/tr[./th/abbr/text()="CLI"]/td[1]/a').InnerText -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://mediaarea.net/download/binary/mediainfo/$($this.CurrentState.Version)/MediaInfo_CLI_$($this.CurrentState.Version)_Windows_i386.zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://mediaarea.net/download/binary/mediainfo/$($this.CurrentState.Version)/MediaInfo_CLI_$($this.CurrentState.Version)_Windows_x64.zip"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://mediaarea.net/download/binary/mediainfo/$($this.CurrentState.Version)/MediaInfo_CLI_$($this.CurrentState.Version)_Windows_ARM64.zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MediaArea/MediaInfo/master/History_CLI.txt').RawContentStream)

      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String.Contains("Version $($this.CurrentState.Version)")) {
          try {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [regex]::Match($String, '(\d{4}-\d{1,2}-\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
          } catch {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          $null = $Object2.ReadLine()
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^Version [\d\.]+') {
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
