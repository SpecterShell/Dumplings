$Object1 = Invoke-RestMethod -Uri 'https://abaclient-prod.app.abasky.net/release/currentVersion.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en'
  InstallerUrl    = $Object1.msi_en
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de'
  InstallerUrl    = $Object1.msi_de
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'fr'
  InstallerUrl    = $Object1.msi_fr
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'it'
  InstallerUrl    = $Object1.msi_it
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.releaseNotes.en | Format-Text
      }

      # ReleaseNotes (de-DE)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'de-DE'
        Key    = 'ReleaseNotes'
        Value  = $Object1.releaseNotes.de | Format-Text
      }

      # ReleaseNotes (fr-FR)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'fr-FR'
        Key    = 'ReleaseNotes'
        Value  = $Object1.releaseNotes.fr | Format-Text
      }

      # ReleaseNotes (it-IT)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'it-IT'
        Key    = 'ReleaseNotes'
        Value  = $Object1.releaseNotes.it | Format-Text
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
