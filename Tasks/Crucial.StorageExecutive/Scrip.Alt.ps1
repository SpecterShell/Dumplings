$Object1 = Invoke-RestMethod -Uri 'https://www.orderingmemory.com/firmware/version.aspx' -Body @{
  ver     = $this.Status.Contains('New') ? '9.09.092023.03' : $this.LastState.Version
  brand   = 'crucial'
  variant = 'client'
  arch    = 'x64'
  os      = 'windows'
}

if ($Object1.status -eq 'OK') {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $Object1.manualURL
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "StorageExecutive-$($this.CurrentState.Version)-windows-64bit-Setup.exe"
    }
  )
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
