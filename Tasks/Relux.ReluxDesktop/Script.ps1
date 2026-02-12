$Object1 = Invoke-WebRequest -Uri 'http://thelightnet.com/update/updatereluxdesktop.php/' -Body @{
  id0       = $this.Status.Contains('New') ? '25010000' : $this.LastState.Version -replace '\d+', { $String = $_.Value.PadLeft(2, '0'); $String.SubString($String.Length - 2) } -replace '\.'
  idCounter = '1'
  arch      = 'x64'
} | Read-ResponseContent | ConvertFrom-Ini

if ([string]::IsNullOrEmpty($Object1.program.versionString)) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = [regex]::Match($Object1.program.versionString, '(\d+(?:\.\d+)+)').Groups[1].Value
$ShortVersion = $this.CurrentState.Version -replace '(\.0+)+$'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://reluxnet.relux.com/download/reluxdesktop/$($this.CurrentState.Version)/ReluxDesktop_$($this.CurrentState.Version).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://relux.com/release-notes-reluxdesktop' | ConvertFrom-Html
      $Object3 = [System.IO.StringReader]::new(($Object2.SelectSingleNode('//*[@id="wrap"]') | Get-TextContent))

      while ($Object3.Peek() -ne -1) {
        $String = $Object3.ReadLine()
        if ($String -match "^$([regex]::Escape($ShortVersion))") {
          break
        }
      }
      if ($Object3.Peek() -ne -1) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while ($Object3.Peek() -ne -1) {
          $String = $Object3.ReadLine()
          if ($String -match '^(\d{1,2}\.\d{1,2}\.20\d{2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Matches[1], 'dd.MM.yyyy', $null).ToUniversalTime()
          } elseif ($String -notmatch '^\d+(?:\.\d+)+') {
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

      $Object3.Close()
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
