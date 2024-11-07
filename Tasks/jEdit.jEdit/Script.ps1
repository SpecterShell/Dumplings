$ProjectName = 'jedit'
$RootPath = '/jedit'

$Object1 = Invoke-RestMethod -Uri "https://sourceforge.net/projects/${ProjectName}/rss?path=${RootPath}"
$Assets = $Object1.Where({ $_.title.'#cdata-section' -match "^$([regex]::Escape($RootPath))/\d+(?:\.\d+)+/jedit\d+(?:\.\d+)+install\.exe$" })

# Version
$this.CurrentState.Version = [regex]::Match($Assets[0].title.'#cdata-section', "^$([regex]::Escape($RootPath))/([\d\.]+)/").Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.exe') -and $_.title.'#cdata-section'.Contains('install') }, 'First')[0].link | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.exe') -and $_.title.'#cdata-section'.Contains('install') }, 'First')[0].pubDate,
        'ddd, dd MMM yyyy HH:mm:ss "UT"',
        (Get-Culture -Name 'en-US')
      ) | ConvertTo-UtcDateTime -Id 'UTC'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = "https://www.jedit.org/CHANGES$($this.CurrentState.Version.Split('.')[0..1] -join '').txt"
      }

      $Object2 = Invoke-RestMethod -Uri $ReleaseNotesUrl
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = [regex]::Match($Object2, '(?s)\{\{\{\s*(.+)\s*\}\}\}').Groups[1].Value -replace '\{\{\{\s*' -replace '\}\}\}' -replace '^Version \d+(?:\.\d+)+' | Format-Text
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
