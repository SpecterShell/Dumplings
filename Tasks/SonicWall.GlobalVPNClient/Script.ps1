function Read-Installer {
  foreach ($Installer in $this.CurrentState.Installer) {
    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'GVCInstall*.msi' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'GVCInstall*.msi' | Get-Item -Force | Select-Object -First 1
    # Version
    $this.CurrentState.Version = $InstallerFile2 | Read-ProductVersionFromMsi
    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile2 -Algorithm SHA256).Hash
    # ProductCode
    $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $Installer['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
  }
}

$Object1 = $Global:DumplingsStorage.SonicWallApps.Where({ $_.Count -ge 2 -and $_[1] -is [string] -and $_[1].Contains('GVCSetup') -and $_[1].Contains('.exe') }, 'First')[0][1] -replace '^[a-zA-Z0-9]+:I?'
$Object2 = [Newtonsoft.Json.Linq.JArray]::Parse($Object1)

# x86
$Object3 = $Object2.SelectTokens('$..cta_group[?(@.link.href =~ /GVCSetup32\.exe$/)]').Where({ $true }, 'First')[0].ToString() | ConvertFrom-Json
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object3.link.href
}
$Object1 = Invoke-WebRequest -Uri $InstallerX86.InstallerUrl -Method Head
$ETag = $Object1.Headers.ETag[0]

# x64
$Object4 = $Object2.SelectTokens('$..cta_group[?(@.link.href =~ /GVCSetup64\.exe$/)]').Where({ $true }, 'First')[0].ToString() | ConvertFrom-Json
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object4.link.href
}
$Object2 = Invoke-WebRequest -Uri $InstallerX64.InstallerUrl -Method Head
$ETagX64 = $Object2.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagX64 = @($ETagX64)

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

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagX64 = @($ETagX64)

  Read-Installer

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag is unchanged
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (MSI)", 'Info')
  return
}
if ($ETagX64 -in $this.LastState.ETagX64) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (EXE)", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

# Case 4: The ETag has changed, but the SHA256 is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag has changed, but the SHA256 is not', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag
  $this.CurrentState.ETagX64 = $this.LastState.ETagX64 + $ETagX64

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)
$this.CurrentState.ETagX64 = @($ETagX64)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The ETag and the SHA256 have changed, but the version is not
  default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
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
