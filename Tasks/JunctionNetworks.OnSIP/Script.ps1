$Object1 = Invoke-WebRequest -Uri 'https://www.onsip.com/app/download'
$Object2 = $Object1.Links.Where({ try { $_.OuterHtml.Contains('OnSIP for Windows v') } catch {} }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($Object2.OuterHtml, 'v(\d+(?:\.\d+)+)').Groups[1].Value

$Object3 = Invoke-WebRequest -Uri $Object2.href | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = [regex]::Match($Object3.SelectSingleNode('//meta[@http-equiv="refresh"]').Attributes['content'].Value, 'url=(.+)').Groups[1].Value
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = 'https://www.onsip.com/app/release-notes/all'
      }

      $ReleaseNotesUrl = "https://www.onsip.com/app/release-notes/version-$($this.CurrentState.Version)-desktop"
      $Object4 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object4.SelectSingleNode('//div[contains(@class, "post-body")]') | Get-TextContent | Format-Text
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl
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
