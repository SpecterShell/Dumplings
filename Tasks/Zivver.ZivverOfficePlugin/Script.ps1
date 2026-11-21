$Object1 = Invoke-RestMethod -Uri 'https://downloads.zivver.com/officeplugin/installer/version_info.xml'
# en-US
$Object2 = $Object1.application.product.Where({ $_.language -eq '1033' }, 'First')[0].version[-1]
# de-DE
$Object3 = $Object1.application.product.Where({ $_.language -eq '1031' }, 'First')[0].version[-1]
# fr-FR
$Object4 = $Object1.application.product.Where({ $_.language -eq '1036' }, 'First')[0].version[-1]
# nl-NL
$Object5 = $Object1.application.product.Where({ $_.language -eq '1043' }, 'First')[0].version[-1]

if (@(@($Object2, $Object3, $Object4, $Object5) | Sort-Object -Property { $_.name } -Unique).Count -gt 1) {
  $this.Log("en-US version: $($Object2.name)")
  $this.Log("de-DE version: $($Object3.name)")
  $this.Log("fr-FR version: $($Object4.name)")
  $this.Log("nl-NL version: $($Object5.name)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object2.name

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en-US'
  InstallerUrl    = "$($Object2.installationUrl)1033/$($this.CurrentState.Version)/$($Object2.files.file.'#text')"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de-DE'
  InstallerUrl    = "$($Object3.installationUrl)1031/$($this.CurrentState.Version)/$($Object3.files.file.'#text')"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'fr-FR'
  InstallerUrl    = "$($Object4.installationUrl)1036/$($this.CurrentState.Version)/$($Object4.files.file.'#text')"
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'nl-NL'
  InstallerUrl    = "$($Object5.installationUrl)1043/$($this.CurrentState.Version)/$($Object5.files.file.'#text')"
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
