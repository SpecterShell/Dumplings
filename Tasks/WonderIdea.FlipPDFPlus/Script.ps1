$Object1 = Invoke-RestMethod -Uri 'https://panel.flipbuilder.com/client/other/getVersion.php'

# Version
$this.CurrentState.Version = $Object1.standard.windows.newVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = 'https://static.flipbuilder.com/download/flippdf2/Flip_PDF_Plus_x64.zip'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "Flip_PDF_Plus_$($this.CurrentState.Version)_x64.exe"
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
