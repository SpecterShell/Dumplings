$Prefix = 'https://download.kde.org/stable/haruna/'

$Object1 = Invoke-WebRequest -Uri $Prefix

$Prefix += ($Object1.Links.Where({ try { $_.href -match '^(\d+(?:\.\d+)+)/$' } catch {} }).href | Sort-Object -Property { [ChunkVersion]([regex]::Match($_, '^(\d+(?:\.\d+)+)/$').Groups[1].Value) } -Bottom 1)

$Object2 = Invoke-WebRequest -Uri $Prefix

$InstallerName = $Object2.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('x86_64') } catch {} }, 'First')[0].href

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $InstallerName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = (Invoke-RestMethod -Uri 'https://apps.kde.org/haruna/index.xml').Where({ $_.title.Contains($this.CurrentState.RealVersion) }, 'First')

      if ($Object2) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object2[0].description.InnerXml | ConvertFrom-Html | Get-TextContent | Format-Text
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
