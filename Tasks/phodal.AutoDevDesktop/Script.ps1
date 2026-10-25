$Object1 = Invoke-GitHubApi -Uri 'https://api.github.com/repos/phodal/auto-dev/releases?per_page=30'

$Asset = $Object1 | Select-Object -ExpandProperty 'assets' |
  Where-Object -FilterScript { $_.name.EndsWith('.msi') -and $_.name.StartsWith('AutoDev.Desktop-') } |
  Sort-Object -Property { [version]($_.name -replace '^AutoDev\.Desktop-', '' -replace '\.msi$', '') } -Bottom 1

# Version (each component of a release carries its own version; track the desktop MSI)
$this.CurrentState.Version = [regex]::Match($Asset.name, '(\d+(?:\.\d+))').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Asset.browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Release = $Object1.Where({ $_.assets.Where({ $_.id -ceq $Asset.id }, 'First').Count -gt 0 }, 'First')[0]

      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Release.published_at.ToUniversalTime()

      # ReleaseNotesUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotesUrl'
        Value  = $Release.html_url
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
