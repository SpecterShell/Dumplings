function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  # AppsAndFeaturesEntries + ProductCode
  $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      ProductCode = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile | Read-ProductCodeFromBurn
      UpgradeCode = $InstallerFile | Read-UpgradeCodeFromBurn
    }
  )
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

$StartDate = Get-Date -Date (Get-Date -AsUTC -Format 'yyyy-MM')
$EndDate = $this.LastState.Contains('LastDate') ? (Get-Date -Date $this.LastState.LastDate) : (Get-Date -Date '2024-10')

$Found = $false
for ($Date = $StartDate; $Date -gt $EndDate; $Date = $Date.AddMonths(-1)) {
  $InstallerUrl = "https://download.microsoft.com/download/8/8/0/880BCA75-79DD-466A-927D-1ABF1F5454B0/PBIDesktopSetup-$($Date.ToString('yyyy-MM'))_x64.exe"
  $this.Log("Probing ${InstallerUrl}", 'Info')
  $Object1 = Invoke-WebRequest -Uri $InstallerUrl -Method Head -SkipHttpErrorCheck
  if ($Object1.StatusCode -eq 200) {
    # Installer
    $this.CurrentState.Installer += [ordered]@{
      Architecture = 'x64'
      InstallerUrl = $InstallerUrl
    }
    # LastDate
    $this.CurrentState.LastDate = $Date.ToString('yyyy-MM')

    $Found = $true
    break
  }
}

if (-not $Found) {
  $this.Log('The installer URL is unchanged', 'Info')
  # Installer
  $this.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $this.LastState.Installer[0].InstallerUrl
  }
  # LastDate
  $this.CurrentState.LastDate = $this.LastState.LastDate
}

$Object2 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
$ETag = $Object2.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

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

  Read-Installer

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag is unchanged
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
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

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The ETag and the SHA256 have changed, but the version is not
  Default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
