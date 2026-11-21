$Prefix = 'https://www.shutterencoder.com/'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('64bits') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://www.shutterencoder.com/changelog.txt').RawContentStream)

      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String -match "^Version $([regex]::Escape($this.CurrentState.Version))") {
          try {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
              [regex]::Match($String, '(\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value,
              'dd/MM/yyyy',
              $null
            ).ToString('yyyy-MM-dd')
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
          if ($String -notmatch '^Version \d+(?:\.\d+)+ ') {
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

    if (-not $this.Status.Contains('New')) {
      $this.CurrentState = $this.LastState
      $this.CurrentState.Installer = @(
        [ordered]@{
          InstallerUrl = Join-Uri 'https://www.shutterencoder.com/old versions/Windows/' ($this.CurrentState.Installer[0].InstallerUrl | Split-Uri -LeftPart Path | Split-Path -Leaf)
        }
      )
      $this.ResetMessage()
      $this.Config.IgnorePRCheck = $true
      try {
        $this.Submit()
      } catch {
        $_ | Out-Host
        $this.Log($_, 'Warning')
      }
    }
  }
}
