$Object1 = Invoke-WebRequest -Uri 'https://www.ldapadministrator.com/download.htm' | ConvertFrom-Html

# Version
$this.CurrentState.Version = $Object1.SelectSingleNode('//div[contains(@class, "tabs-content__item")][2]//dt[contains(text(), "Version:")]/following-sibling::dd').InnerText.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en-US'
  Architecture    = 'x86'
  InstallerUrl    = "https://downloads.softerra.com/ldapadmin/ldapbrowser-$($this.CurrentState.Version)-x86-eng.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en-US'
  Architecture    = 'x64'
  InstallerUrl    = "https://downloads.softerra.com/ldapadmin/ldapbrowser-$($this.CurrentState.Version)-x64-eng.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de-DE'
  Architecture    = 'x86'
  InstallerUrl    = "https://downloads.softerra.com/ldapadmin/ldapbrowser-$($this.CurrentState.Version)-x86-deu.msi"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de-DE'
  Architecture    = 'x64'
  InstallerUrl    = "https://downloads.softerra.com/ldapadmin/ldapbrowser-$($this.CurrentState.Version)-x64-deu.msi"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        [regex]::Match($Object1.SelectSingleNode('//div[contains(@class, "tabs-content__item")][2]//dt[contains(text(), "Release Date:")]/following-sibling::dd').InnerText.Trim(), '(\d{1,2}/\d{1,2}/20\d{2})').Groups[1].Value,
        'MM/dd/yyyy',
        $null
      ).ToString('yyyy-MM-dd')
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
