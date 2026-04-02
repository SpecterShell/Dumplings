# x86
$Object1 = $Global:DumplingsStorage.PythonVersions.versions.Where({ $_.'install-for'.Contains('3.14-32') }, 'First')[0]
# x64
$Object2 = $Global:DumplingsStorage.PythonVersions.versions.Where({ $_.'install-for'.Contains('3.14-64') }, 'First')[0]
# arm64
$Object3 = $Global:DumplingsStorage.PythonVersions.versions.Where({ $_.'install-for'.Contains('3.14-arm64') }, 'First')[0]

if (@(@($Object1, $Object2, $Object3) | Sort-Object -Property { $_.'sort-version' } -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x86: $($Object1.'sort-version'), x64: $($Object2.'sort-version'), arm64: $($Object3.'sort-version')", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object2.'sort-version'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Join-Uri $Object1.url "python-$($this.CurrentState.Version).exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Object2.url "python-$($this.CurrentState.Version)-amd64.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Join-Uri $Object3.url "python-$($this.CurrentState.Version)-arm64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl = "https://docs.python.org/release/$($this.CurrentState.Version)/whatsnew/changelog.html"
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesNode = $Object2.SelectSingleNode("//*[@id='python-$($this.CurrentState.Version.Replace('.', '-'))-final']")

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
