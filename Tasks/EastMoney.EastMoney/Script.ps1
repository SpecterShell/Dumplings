function Get-Version {
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'config/app_cfg.xml' | Out-Host
  $Object2 = Join-Path $InstallerFileExtracted 'app_cfg.xml' | Get-Item | Get-Content -Raw | ConvertFrom-Xml
  $this.CurrentState.Version = [regex]::Match($Object2.root.app.name, '(\d+\.\d+\.\d+)').Groups[1].Value
}

$Object1 = Invoke-WebRequest -Uri 'https://emdesk.eastmoney.com/pc_activity/Pages/VIPTrade/pages/' | ConvertFrom-Html

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https:' + $Object1.SelectSingleNode('//a[@id="down-a"]').Attributes['href'].Value
}

$Object2 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# MD5
$this.CurrentState.MD5 = $Object2.Headers.'Content-MD5'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  Get-Version
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is newly created
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  Get-Version
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

  $this.Print()
  $this.Write()
  return
}

# Case 2: The MD5 was not updated
if ($this.CurrentState.MD5 -eq $this.LastState.MD5) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
# Version
Get-Version
# InstallerSha256
$this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

# Case 3: The installer file has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

switch -Regex ($this.Check()) {
  # Case 5: The MD5 and the version were updated
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 4: The MD5 was updated, but the version wasn't
  # The installer might be updated without changing the version (e.g., virus database update)
  # Force submit the manifest even if neither the version nor the installer has changed
  Default {
    $this.Log('The MD5 was changed, but the version is the same', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
