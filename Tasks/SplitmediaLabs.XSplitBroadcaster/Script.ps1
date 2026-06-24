# $Object1 = Invoke-WebRequest -Uri 'https://cdn.xsplit.com/updater/login/update.aiu' | Read-ResponseContent -Encoding 'windows-1252' | ConvertFrom-Ini
$Object1 = Invoke-WebRequest -Uri 'https://cdn.xsplit.com/updater/manual/update.aiu' | Read-ResponseContent -Encoding 'windows-1252' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Update.ProductVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType = 'msi'
  InstallerUrl  = $Object1.Update.URL -replace '\.exe$', '.msi'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
