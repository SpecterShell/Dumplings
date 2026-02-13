$Object1 = (Invoke-RestMethod -Uri 'https://www.python.org/api/v2/downloads/release/?version=3&pre_release=false' -MaximumRetryCount 0) |
  Where-Object -FilterScript { $_.name.Contains('3.13.') } |
  Sort-Object -Property { $_.name -replace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

$Object2 = (Invoke-RestMethod -Uri "https://www.python.org/api/v2/downloads/release_file/?os=1&release=$([regex]::Match($Object1.resource_uri, 'release/(\d+)/').Groups[1].Value)" -MaximumRetryCount 0)

# Version
$this.CurrentState.Version = $Version = [regex]::Match($Object1.name, 'Python ([\d\.]+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.Where({ $_.name.Contains('installer') -and $_.name -match '32\s*-bit' }, 'First')[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object2.Where({ $_.name.Contains('installer') -and $_.name -match '64\s*-bit' }, 'First')[0].url
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object2.Where({ $_.name.Contains('installer') -and $_.name -match 'ARM64' }, 'First')[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = [string]::IsNullOrWhiteSpace($Object1.release_notes_url) ? "https://docs.python.org/release/$($this.CurrentState.Version)/whatsnew/changelog.html" : $Object1.release_notes_url
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl -MaximumRetryCount 0 | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@id='python-$($Version.Replace('.', '-'))-final']")

      # ReleaseTime
      $this.CurrentState.ReleaseTime = [regex]::Match(
        $ReleaseNotesNode.SelectSingleNode('./p[1]//text()').InnerText,
        '(\d{4}-\d{1,2}-\d{1,2})'
      ).Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = ($ReleaseNotesNode.SelectNodes('./p[1]/following-sibling::node()') | Get-TextContent | Format-Text).Replace('¶', '')
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
