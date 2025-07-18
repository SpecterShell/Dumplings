$Object1 = Invoke-RestMethod -Uri 'https://autoupdate.opera.com/' -Method Post -Body @"
<?xml version="1.0"?>
<autoupdate schema-version="2.2" type="manual">
  <system>
    <platform>
      <opsys>Windows</opsys>
      <opsys-arch>x86_64</opsys-arch>
      <opsys-version>10</opsys-version>
      <arch>x64</arch>
      <package>EXE</package>
    </platform>
  </system>
  <product>
    <name>Opera GX</name>
    <version>$($this.Status.Contains('New') ? '119.0.5497.43' : $this.LastState.Version)</version>
  </product>
</autoupdate>
"@

if ($Object1.GetElementsByTagName('product').Count -eq 0) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.autoupdate.product.files.file.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://get.geo.opera.com/pub/opera_gx/$($this.CurrentState.Version)/win/Opera_GX_$($this.CurrentState.Version)_Setup.exe"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://get.geo.opera.com/pub/opera_gx/$($this.CurrentState.Version)/win/Opera_GX_$($this.CurrentState.Version)_Setup_x64.exe"
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
