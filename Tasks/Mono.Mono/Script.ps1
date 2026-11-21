$Object1 = Invoke-WebRequest -Uri 'https://www.mono-project.com/docs/about-mono/releases/'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'The latest stable release is (\d+(?:\.\d+)+)').Groups[1].Value

$Prefix = "https://download.mono-project.com/archive/$($this.CurrentState.Version.Split('.')[0..2] -join '.')/windows-installer/"

$Object2 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri $Prefix $Object2.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains($this.CurrentState.Version) -and $_.href.Contains('win32') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $Object2.Links.Where({ try { $_.href.EndsWith('.msi') -and $_.href.Contains($this.CurrentState.Version) -and $_.href.Contains('x64') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://www.mono-project.com/docs/about-mono/releases/'
      }

      $Object3 = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/mono/website/gh-pages/docs/about-mono/releases/$($this.CurrentState.Version).md" | Convert-MarkdownToHtml
      $Object4 = $Object3.SelectSingleNode('/h2[1]').InnerText | ConvertFrom-Yaml

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object4.releasedate | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object3.SelectNodes('/h2[1]/following-sibling::node()') | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://www.mono-project.com/docs/about-mono/releases/$($this.CurrentState.Version)/"
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
