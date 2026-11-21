$Object1 = Invoke-RestMethod -Uri 'https://www.larksuite.com/api/rooms/downloads' -Headers @{ cookie = '__tea__ug__uid=1' }

# Version
$this.CurrentState.Version = $Object1.data.version.room.windows.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.version.room.windows.download_link
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
