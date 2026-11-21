$Object1 = Invoke-WebRequest -Uri 'https://www.registradores.org/d2versiones/VersionesD2.htm'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'D2_2025=(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'burn'
  InstallerUrl  = 'https://www.registradores.org/d2versiones/Instalar_D2_2025.exe'
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
