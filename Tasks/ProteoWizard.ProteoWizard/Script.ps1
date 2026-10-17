$Object1 = Invoke-RestMethod -Uri 'https://proteowizard.sourceforge.io/releases/bt83.xml'

$Artifact = [string]$Object1.artifacts.artifact.Where({ $_ -like '*/content/ProteoWizard-WithVendorSdks-Setup-*.exe' }, 'First')
if ($Artifact -notmatch '/guestAuth/app/rest/builds/id:(?<BuildId>\d+)/artifacts/content/(?<FileName>ProteoWizard-WithVendorSdks-Setup-(?<Version>\d+\.\d+\.\d+)-[0-9a-f]+\.exe)') {
  throw "No ProteoWizard x64 MSI artifact was found in bt83.xml: $Artifact"
}

# Version
$this.CurrentState.Version = $Matches.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = "https://mc-tca-01.s3.us-west-2.amazonaws.com/ProteoWizard/bt83/$($Matches.BuildId)/$($Matches.FileName)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
    $this.Submit()
  }
}
