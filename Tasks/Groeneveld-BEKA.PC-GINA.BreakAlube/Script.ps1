$Page = Invoke-WebRequest -Uri 'https://www.groeneveld-beka.com/software/'
$Link = $Page.Links.Where({ try { $_.href -match 'PC-?GINA' -and $_.href -match 'BreakAlube' -and $_.href.EndsWith('.zip') } catch {} }, 'First')[0].href

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerType       = 'zip'
  NestedInstallerType = 'exe'
  InstallerUrl        = $Link
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
    $this.CurrentState.Installer[0]['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.Name.EndsWith('.exe') }, 'First')[0].FullName.Replace('/', '\') })
    $ZipFile.Dispose()

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
