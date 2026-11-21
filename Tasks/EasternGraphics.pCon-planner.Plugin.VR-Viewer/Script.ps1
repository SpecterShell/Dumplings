$Object1 = Invoke-RestMethod -Uri 'https://download-center.pcon-solutions.com/index.php?rest_route=/wp/v2/posts/933'
$Links = $Object1.content.rendered | Get-EmbeddedLinks

# Version
$this.CurrentState.Version = [regex]::Match($Object1.title.rendered, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Links.Where({ try { $_.href.EndsWith('.exe') } catch {} }, 'First')[0].href
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('History') } catch {} }, 'First')[0].href
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
