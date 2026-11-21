$Prefix = 'https://gnupg.org'

$Object1 = Invoke-WebRequest -Uri "${Prefix}/download/index.html"

$InstallerName = $Object1.Links.Where({ try { $_.href -match 'gnupg-w32-[\d\.]+_\d+\.exe$' } catch {} }, 'First')[0].href

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, 'gnupg-w32-([\d\.]+)_\d+\.exe').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Prefix + $InstallerName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact([regex]::Match($InstallerName, 'gnupg-w32-[\d\.]+_(\d+)\.exe').Groups[1].Value, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://git.gnupg.org/cgi-bin/gitweb.cgi?p=gnupg.git;a=blob_plain;f=NEWS;hb=HEAD').RawContentStream)

      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String.Contains("Changes also found in $($this.CurrentState.Version)")) {
          break
        } elseif ($String.Contains("Noteworthy changes in version $($this.CurrentState.Version)")) {
          $Object2.ReadLine() | Out-Null
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if (-not $String.Contains('Changes also found in') -and $String -notmatch '^\S+') {
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
