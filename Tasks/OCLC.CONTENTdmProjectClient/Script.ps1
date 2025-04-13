$Object1 = Invoke-WebRequest -Uri 'https://help.oclc.org/Metadata_Services/CONTENTdm/Project_Client/Project_Client_overview/Download_the_Project_Client'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.Content, 'CONTENTdm Project Client (\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.msi') } catch {} }, 'First')[0].href
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
