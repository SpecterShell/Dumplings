$ReleaseNotesUrl = 'https://www.thunderheadeng.com/docs/latest/ventus/'
$Object1 = Invoke-WebRequest -Uri $ReleaseNotesUrl
$ReleaseNotesUrl = Join-Uri $ReleaseNotesUrl ([regex]::Match($Object1.Content, 'location.href="([^"]+)"').Groups[1].Value)
$Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = [regex]::Match($Object2.Content, '"(https://www.thunderheadeng.net/releases/Ventus-[^"]+?\.msi)"').Groups[1].Value
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:-\d+)+)').Groups[1].Value.Replace('-', '.') -replace '^20'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrl
      }

      $Object3 = $Object2 | ConvertFrom-Html
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object3.SelectSingleNode('//main') | Get-TextContent | Format-Text
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
    if ("20$($this.CurrentState.Version.Split('.')[0])" -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Config.WinGetNewPackageIdentifier = $this.Config.WinGetIdentifier -replace '20\d{2}', "20$($this.CurrentState.Version.Split('.')[0])"
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'PackageName'
        Value  = { $_ -replace '20\d{2}', "20$($this.CurrentState.Version.Split('.')[0])" }
      }
    }
    $this.Submit()
  }
}
