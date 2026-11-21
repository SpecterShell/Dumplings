$Object1 = Invoke-WebRequest -Uri 'https://krowork.com/zh/index'

# The download button reads the installer URLs from its Astro chunk
$HeroHeaderUrl = [regex]::Match($Object1.Content, 'https://[^\s"''<>]+/HeroHeader[^\s"''<>]*\.js').Value
$Object2 = Invoke-WebRequest -Uri $HeroHeaderUrl
$Object3 = Invoke-WebRequest -Uri (Join-Uri (Split-Uri $HeroHeaderUrl -Parent) ([regex]::Match($Object2.Content, '"\./(download[^"]*\.js)"').Groups[1].Value))

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = [regex]::Match($Object3.Content, 'https://[^\s"''""]+/windows-x86_64/KroWork-\d+(?:\.\d+)+-setup\.exe').Value
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, 'KroWork-(\d+(?:\.\d+)+)-setup\.exe').Groups[1].Value

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
