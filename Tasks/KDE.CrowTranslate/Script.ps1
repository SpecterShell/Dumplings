$Object1 = Invoke-RestMethod -Uri 'https://apps.kde.org/crowtranslate/index.xml'

# Version
$this.CurrentState.Version = [regex]::Match($Object1[0].guid, '#(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1[0].artifacts.artifact.Where({ $_.platform -eq 'x86_64-windows-msvc' -and $_.location.src.EndsWith('.exe') }, 'First')[0].location.src
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesObject = $Object1[0].description.InnerXml | ConvertFrom-Html
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesObject.ChildNodes[0]; $Node -and -not $Node.SelectSingleNode('.//a[contains(@href, "download.kde.org")]'); $Node = $Node.NextSibling) { $Node }
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1[0].link
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