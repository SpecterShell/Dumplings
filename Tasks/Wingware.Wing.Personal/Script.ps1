$Object1 = Invoke-RestMethod -Uri 'https://wingware.com/update' -Method Post -Body @{
  protocol     = '1'
  prod         = 'wing-personal'
  osname       = 'win32'
  from_version = $this.Status.Contains('New') ? '10.0.5.0' : $this.LastState.Version
  page         = 'update'
  noheader     = '1'
}
$Object2 = [regex]::Match($Object1, 'NEWER:(\d+(?:\.\d+)+)')

if (-not $Object2.Success) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object2.Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://wingware.com/pub/wing-personal/$($this.CurrentState.Version)/wing-personal-$($this.CurrentState.Version).exe"
  ProductCode  = "Wing Personal $($this.CurrentState.Version.Split('.')[0])_is1"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = "https://wingware.com/pub/wing-personal/$($this.CurrentState.Version)/CHANGELOG.txt"
      }

      $Object3 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream)

      while (-not $Object3.EndOfStream) {
        $String = $Object3.ReadLine()
        if ($String -match "Release $([regex]::Escape($this.CurrentState.Version.Split('.')[0..2] -join '.'))") {
          break
        }
      }
      if (-not $Object3.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object3.EndOfStream) {
          $String = $Object3.ReadLine()
          if ($String -match '^-+$|^Priority:') {
            continue
          }
          if ($String -match '^Date:') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [regex]::Match($String, '([a-zA-Z]+\W+\d{1,2}\W+20\d{1,2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
            continue
          }
          if ($String -match '^(?:Release|Update) ') {
            break
          }
          $ReleaseNotesObjects.Add($String)
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

    try {
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
