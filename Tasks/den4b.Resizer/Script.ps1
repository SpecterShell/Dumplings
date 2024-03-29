$Object1 = Invoke-WebRequest -Uri 'https://www.den4b.com/changelogs/resizer' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectNodes('//tbody[@class="changelogVersionBlock" and contains(./tr[1]/@class, "bg-success")][1]/tr[1]/td[1]/strong').InnerText.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://www.den4b.com/download/resizer/installer/$($this.CurrentState.Version)?token=winget"
}

$this.CurrentState.ReleaseTime = $Object1.SelectSingleNode("//tbody[@id='v$($this.CurrentState.Version)']/tr[1]/td[2]").InnerText.Trim() | Get-Date -Format 'yyyy-MM-dd'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://www.den4b.com/news.atom').Where({ $_.title.Contains('Resizer') -and $_.title.Contains($this.CurrentState.Version) }, 'First')

      if ($Object2) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].content.'#text' | ConvertFrom-Html | Get-TextContent | Format-Text
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
