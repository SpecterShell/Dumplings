function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'install.7z' | Out-Host
  $InstallerFile2 = Join-Path $InstallerFileExtracted 'install.7z'
  # Version
  $this.CurrentState.Version = [regex]::Match((7z.exe l -ba -slt $InstallerFile2), 'Path = (\d+\.\d+\.\d+\.\d+)').Groups[1].Value
  Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

$Object1 = Invoke-WebRequest -Uri 'https://pc.weixin.qq.com/' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('//a[@id="downloadButton"]').Attributes['href'].Value
}

# Hash
$this.CurrentState.Hash = (Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head).Headers.'X-COS-META-MD5'[0]

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
  # Case 5: The hash and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 4: The hash has changed, but the version is not
  default {
    $this.Log('The hash has changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
