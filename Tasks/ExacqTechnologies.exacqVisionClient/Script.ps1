$Object1 = Invoke-RestMethod -Uri 'https://www.exacq.com/downloads/evFileInfo.txt' | ConvertFrom-Ini

if ($Object1.'ev-Client-x64'.Version -ne $Object1.'ev-Client-x64-msi'.Version) {
  throw 'Distinct versions detected'
}

# Version
$this.CurrentState.Version = $Object1.'ev-Client-x64-msi'.Version
$ShortVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = $Object1.'ev-Client-x64-msi'.Link | ConvertTo-Https
}
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'nullsoft'
  InstallerUrl  = $Object1.'ev-Client-x64'.Link | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Object1.'ev-Client-x64-msi'.Date, 'M/d/yyyy', $null).Tostring('yyyy-MM-dd')
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object4 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://crm.exacq.com/support/releasenotes/release_notes.php?filepath=/var/www/release/evclientRelNotes.txt').RawContentStream)

      while (-not $Object4.EndOfStream) {
        $String = $Object4.ReadLine()
        if ($String -match "v${ShortVersion}") {
          break
        }
      }
      if (-not $Object4.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object4.EndOfStream) {
          $String = $Object4.ReadLine()
          if ($String -notmatch '^\d{1,2}/\d{1,2}/\d{4}') {
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
