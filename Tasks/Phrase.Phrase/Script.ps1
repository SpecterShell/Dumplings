$Object1 = Invoke-RestMethod -Uri 'https://cloud.memsource.com/web/systemInfo/json'

# Version
$this.CurrentState.Version = $Object1.translationEditor3PartVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.memsource.com/production/updates/memsource-editor/win/archive/install/Phrase-$($this.CurrentState.Version)-windows.exe"
  ProductCode  = "Phrase $($this.CurrentState.Version)"
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
