$Object1 = Invoke-RestMethod -Uri 'https://www.ldapadministrator.com/support/update/info41.php' -Body @{
  version = $this.Status.Contains('New') ? '4.22.27007.0' : $this.LastState.Version
}

# Version
$this.CurrentState.Version = $Object1.latestversion.buildnumber

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en-US'
  Architecture    = 'x86'
  InstallerUrl    = "https://downloads.softerra.com/ldapadmin/ldapadmin-$($this.CurrentState.Version)-x86-eng.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en-US'
  Architecture    = 'x64'
  InstallerUrl    = "https://downloads.softerra.com/ldapadmin/ldapadmin-$($this.CurrentState.Version)-x64-eng.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de-DE'
  Architecture    = 'x86'
  InstallerUrl    = "https://downloads.softerra.com/ldapadmin/ldapadmin-$($this.CurrentState.Version)-x86-deu.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de-DE'
  Architecture    = 'x64'
  InstallerUrl    = "https://downloads.softerra.com/ldapadmin/ldapadmin-$($this.CurrentState.Version)-x64-deu.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.latestversion.releasedate | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.latestversion.releasenotesurl | ConvertTo-Https
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
    if ($Object1.latestversion.productversion -ne $this.Config.WinGetIdentifier.Split('.')[-1]) {
      $this.Log("The WinGet package needs to be updated to the version $($Object1.latestversion.productversion)", 'Error')
    } else {
      $this.Submit()
    }
  }
}
