$Prefix = 'https://productstore.clarity.dexcom.com/'
$Object1 = Invoke-RestMethod -Uri $Prefix
$Object2 = $Object1.ListBucketResult.Contents.Where({ $_.Key.EndsWith('.msi') }, 'First')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object2.Key
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
