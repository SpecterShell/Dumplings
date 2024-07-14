function Get-Version {
  $this.CurrentState.Version = [regex]::Match((7z.exe e -y -so $InstallerFile '$PLUGINSDIR\install-tl-*\tlpkg\TeXLive\TLConfig.pm'), '\$ReleaseYear\s*=\s*(\d+)').Groups[1].Value
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl = 'http://dante.ctan.org/tex-archive/systems/texlive/tlnet/install-tl-windows.exe'
}

# SHA512
$this.CurrentState.SHA512 = (Invoke-RestMethod -Uri "${InstallerUrl}.sha512").Split()[0]

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

# Case 2: The SHA512 was not updated
if ($this.CurrentState.SHA512 -eq $this.LastState.SHA512) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri $InstallerUrl
# Version
Get-Version
# InstallerSha256
$this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

# Case 3: The installer file has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

switch -Regex ($this.Check()) {
  # Case 5: The SHA512 and the version were updated
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 4: The SHA512 was updated, but the version wasn't
  # The installer might be updated without changing the version (e.g., virus database update)
  # Force submit the manifest even if neither the version nor the installer has changed
  Default {
    $this.Log('The SHA512 was changed, but the version is the same', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
