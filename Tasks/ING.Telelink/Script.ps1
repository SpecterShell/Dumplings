function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'Telelink6.msi' | Out-Host
  $InstallerFile2 = Join-Path $InstallerFileExtracted 'Telelink6.msi'
  # Version
  $this.CurrentState.Version = $InstallerFile2 | Read-ProductVersionFromMsi
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  # ProductCode
  $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
  # AppsAndFeaturesEntries
  $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
      InstallerType = 'msi'
    }
  )
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

$Object1 = Invoke-WebRequest -Uri 'https://api.www.ing.be/be/public/pagemodel?pageUrl=/en/business/payments/telelink-isabel'
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = [Newtonsoft.Json.Linq.JObject]::Parse($Object1.Content).SelectTokens('$..[?(@ =~ /Telelink.+\.zip$/)]').Where({ $true }, 'First')[0].ToString()
}

$Object2 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# Content Length
$this.CurrentState.ContentLength = $Object2.Headers.'Content-Length'[0]

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

# Case 2: The Content Length is unchanged
if ($this.CurrentState.ContentLength -eq $this.LastState.ContentLength) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

switch -Regex ($this.Check()) {
  # Case 4: The Content Length and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 3: The Content Length has changed, but the version is not
  default {
    $this.Log('The Content Length and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
