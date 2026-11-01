function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
  $this.CurrentState.Installer[0]['NestedInstallerFiles'] = @([ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.Name.EndsWith('.exe') }, 'First')[0].FullName.Replace('/', '\') })
  $ZipFile.Dispose()
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
  $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
  # Version
  $this.CurrentState.Version = $InstallerFile2 | Read-ProductVersionFromExe
  Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'nullsoft'
  InstallerUrl        = 'https://file-assets.hifox.com/download/HiFox-windows-x64-latest.zip'
}

$this.CurrentState.Hash = (Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head).Headers.'x-oss-hash-crc64ecma'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  return
}

# Case 2: The hash is unchanged
if ($this.CurrentState.Hash -eq $this.LastState.Hash) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

switch -Regex ($this.Check()) {
  # Case 4: The hash and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The hash has changed, but the version has not
  default {
    $this.Log('The hash has changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
