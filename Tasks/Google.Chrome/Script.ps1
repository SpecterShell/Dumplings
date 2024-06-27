# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise.msi'
}
$Object1 = Invoke-WebRequest -Uri $InstallerX86.InstallerUrl -Method Head -Headers @{'If-Modified-Since' = $this.LastState['LastModifiedX86'] } -SkipHttpErrorCheck
if ($Object1.StatusCode -eq 304) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi'
}
$Object2 = Invoke-WebRequest -Uri $InstallerX64.InstallerUrl -Method Head -Headers @{'If-Modified-Since' = $this.LastState['LastModifiedX64'] } -SkipHttpErrorCheck
if ($Object2.StatusCode -eq 304) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise_arm64.msi'
}
$Object3 = Invoke-WebRequest -Uri $InstallerARM64.InstallerUrl -Method Head -Headers @{'If-Modified-Since' = $this.LastState['LastModifiedARM64'] } -SkipHttpErrorCheck
if ($Object3.StatusCode -eq 304) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$InstallerX64File = Get-TempFile -Uri $InstallerX64.InstallerUrl

# InstallerSha256 + AppsAndFeaturesEntries
$InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerX64File -Algorithm SHA256).Hash
$InstallerX64['AppsAndFeaturesEntries'] = @(
  [ordered]@{
    ProductCode = $InstallerX64['ProductCode'] = $InstallerX64File | Read-ProductCodeFromMsi
    UpgradeCode = $InstallerX64File | Read-UpgradeCodeFromMsi
  }
)

# Version
$this.CurrentState.Version = (Read-MsiSummaryValue -Path $InstallerX64File -Name Comments).Split(' ')[0].Trim()

# LastModified
$this.CurrentState.LastModifiedX86 = $Object1.Headers.'Last-Modified'[0]
$this.CurrentState.LastModifiedX64 = $Object2.Headers.'Last-Modified'[0]
$this.CurrentState.LastModifiedARM64 = $Object3.Headers.'Last-Modified'[0]

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
