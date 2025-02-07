$Object1 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/mono/website/gh-pages/_data/latestrelease.yml' | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = [regex]::Match($Object1.version, '\((.+)\)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.mono_windows_url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.mono_windows64_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/mono/website/gh-pages/docs/about-mono/releases/$($this.CurrentState.Version).md" | Convert-MarkdownToHtml
      $Object3 = $Object2.SelectSingleNode('/h2[1]').InnerText | ConvertFrom-Yaml

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object3.releasedate | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('/h2[1]/following-sibling::node()') | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://www.mono-project.com/docs/about-mono/releases/$($this.CurrentState.Version)/"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://www.mono-project.com/docs/about-mono/releases/'
      }
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
