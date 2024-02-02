$Prefix = 'https://ftpmirror.gnu.org/octave/windows/'

$Object1 = Invoke-WebRequest -Uri $Prefix | ConvertFrom-Html

$InstallerName = $Object1.SelectNodes('/html/body/pre/a').ForEach({ $_.Attributes['href'].Value }) |
  Where-Object -FilterScript { $_.EndsWith('installer.exe') -and $_.Contains('w64') -and -not $_.Contains('-64') } |
  Sort-Object -Property { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) } -Bottom 1

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, '(\d+\.\d+\.\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Scope        = 'user'
  InstallerUrl = "${Prefix}${InstallerName}"
  ProductCode  = "Octave-${InstallerName} (Local)"
}
$this.CurrentState.Installer += [ordered]@{
  Scope        = 'machine'
  InstallerUrl = "${Prefix}${InstallerName}"
  ProductCode  = "Octave-${InstallerName}"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://octave.org/feed.xml').Where({ $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object2[0].link
        }
      } else {
        $this.Logging("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = 'https://octave.org/news.html'
        }
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://octave.org/news.html'
      }
    }

    try {
      if ($Object2) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = $Object2[0].pubDate | Get-Date -AsUTC

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].description | ConvertFrom-Html | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
