$Object1 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://marcedit.reeset.net/software/update75.php').RawContentStream)

# Version
$this.CurrentState.Version = $Object1.ReadLine().Trim()
$ShortVersion = $this.CurrentState.Version.Split('.')[0..1] -join '.'

$Object2 = Invoke-WebRequest -Uri 'https://marcedit.reeset.net/downloads'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType          = 'exe'
  Scope                  = 'user'
  InstallerUrl           = $Object2.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('User_Install') } catch {} }, 'First')[0].href
  ProductCode            = "MarcEdit ${ShortVersion} (User) $($this.CurrentState.Version)"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayName = "MarcEdit ${ShortVersion} (User) User Installation (Self Contained)"
    }
  )
}

$Object3 = Invoke-WebRequest -Uri 'https://marcedit.reeset.net/managing-marcedit-installations'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  Scope         = 'machine'
  InstallerUrl  = $Object3.Links.Where({ try { $_.href.EndsWith('.msi') } catch {} }, 'First')[0].href
  ProductCode   = "MarcEdit ${ShortVersion} $($this.CurrentState.Version)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if (-not $Object1.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object1.EndOfStream) {
          $String = $Object1.ReadLine()
          if ($String -match '^\d+(\.\d+)+$') {
            break
          } elseif ($String.Contains('PCode')) {
            continue
          } elseif ($String -match 'Updated: (\d{1,2}/\d{1,2}/20\d{2})') {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Matches[1], 'M/d/yyyy', $null).ToString('yyyy-MM-dd')
          } else {
            $ReleaseNotesObjects.Add($String)
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
  { $true } {
    $Object1.Close()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
