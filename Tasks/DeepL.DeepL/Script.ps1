$Object1 = (Invoke-RestMethod -Uri 'https://appdownload.deepl.com/windows/x64/RELEASES').Split(' ')

# Version
$this.CurrentState.Version = [regex]::Match($Object1[1], 'DeepL-([\d\.]+)-full\.nupkg').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://appdownload.deepl.com/windows/full/$($this.CurrentState.Version.Replace('.', '_'))/DeepLSetup.exe"
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
