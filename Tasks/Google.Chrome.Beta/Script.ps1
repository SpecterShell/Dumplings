# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://dl.google.com/dl/chrome/install/beta/googlechromebetastandaloneenterprise.msi'
}
$Object1 = Invoke-WebRequest -Uri $InstallerX86.InstallerUrl -Method Head
$this.CurrentState.ETagX86 = $Object1.Headers.ETag[0]
if (-not $Global:DumplingsPreference.Contains('Force') -and -not $this.Status.Contains('New') -and $this.CurrentState.ETagX86 -eq $this.LastState.ETagX86) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://dl.google.com/dl/chrome/install/beta/googlechromebetastandaloneenterprise64.msi'
}
$Object2 = Invoke-WebRequest -Uri $InstallerX64.InstallerUrl -Method Head
$this.CurrentState.ETagX64 = $Object2.Headers.ETag[0]
if (-not $Global:DumplingsPreference.Contains('Force') -and -not $this.Status.Contains('New') -and $this.CurrentState.ETagX64 -eq $this.LastState.ETagX64) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = 'https://dl.google.com/dl/chrome/install/beta/googlechromebetastandaloneenterprise_arm64.msi'
}
$Object3 = Invoke-WebRequest -Uri $InstallerARM64.InstallerUrl -Method Head
$this.CurrentState.ETagARM64 = $Object3.Headers.ETag[0]
if (-not $Global:DumplingsPreference.Contains('Force') -and -not $this.Status.Contains('New') -and $this.CurrentState.ETagARM64 -eq $this.LastState.ETagARM64) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$InstallerX64File = Get-TempFile -Uri $InstallerX64.InstallerUrl

# Version
$this.CurrentState.Version = (Read-MsiSummaryValue -Path $InstallerX64File -Name Comments).Split(' ')[0].Trim()

# InstallerSha256 + AppsAndFeaturesEntries
$InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerX64File -Algorithm SHA256).Hash
$InstallerX64['AppsAndFeaturesEntries'] = @(
  [ordered]@{
    ProductCode = $InstallerX64['ProductCode'] = $InstallerX64File | Read-ProductCodeFromMsi
    UpgradeCode = $InstallerX64File | Read-UpgradeCodeFromMsi
  }
)

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
