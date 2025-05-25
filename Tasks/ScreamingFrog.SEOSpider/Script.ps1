# Version
$this.CurrentState.Version = (Invoke-WebRequest -Uri 'https://download.screamingfrog.co.uk/products/seo-spider/getlatestversion.php').Content.Trim()

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://download.screamingfrog.co.uk/products/seo-spider/ScreamingFrogSEOSpider-$($this.CurrentState.Version).exe"
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
