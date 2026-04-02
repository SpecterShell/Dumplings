$Object1 = Invoke-RestMethod -Uri 'https://www.smarttech.com/_api/SoftwareDownloadTypes?FolderID=%7B68EC019A-56BC-4E16-8464-6463C51D65D0%7D'

for ($i = 1; $i -lt 5; $i++) {
  if ($Object1[0]."WindowsDescription${i}" -eq 'MSI installer') {
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      InstallerUrl = $Object1[0]."WindowsLink${i}"
    }
    break
  }
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+){3})').Groups[1].Value

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
