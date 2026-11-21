$Object1 = Invoke-WebRequest -Uri 'https://www.bento4.com/downloads/'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('x86_64') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = '{0}.{1}.{2}-{3}' -f [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+)-(\d+)-(\d+)-(\d+)').Groups[1..4].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
      $Installer['NestedInstallerFiles'] = $ZipFile.Entries.Where({ $_.FullName -match 'bin/[^/]+\.exe$' }).ForEach({
          [ordered]@{
            RelativeFilePath = $_.FullName.Replace('/', '\')
          }
        })
      $ZipFile.Dispose()
    }

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
