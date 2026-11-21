$Object1 = Invoke-RestMethod -Uri 'https://youniverse.lucanet.com/rest/update/v1/assemblies/'

# The catalog gates every program version on a minimum Software Manager release
# (minLnSwMgrReleaseId); the newest of these that Lucanet publishes on the CDN is the current installer
$ReleaseIds = [System.Collections.Generic.List[string]]::new()
foreach ($Assembly in @($Object1)) {
  $Object2 = Invoke-RestMethod -Uri "https://youniverse.lucanet.com$($Assembly.url)"
  foreach ($Descriptor in @($Object2)) {
    if ($Descriptor.minLnSwMgrReleaseId) { $ReleaseIds.Add($Descriptor.minLnSwMgrReleaseId) }
  }
}

$SortedReleases = @($ReleaseIds | Select-Object -Unique | ForEach-Object {
    if ($_ -match '^(\d{2})(\d{2})\+(\d+)$') {
      [PSCustomObject]@{ Id = $_; SortKey = [long]('{0}{1}{2:d4}' -f $Matches[1], $Matches[2], [int]$Matches[3]) }
    }
  } | Sort-Object -Property SortKey -Descending)

foreach ($Release in $SortedReleases) {
  $InstallerUrl = "https://cdn.lucanet.com/installer/LucaNet.SoftwareManager_Installer_$($Release.Id).msi"
  if ((Invoke-WebRequest -Uri $InstallerUrl -Method Head -SkipHttpErrorCheck).StatusCode -eq 200) {
    break
  }
}

# Version
$this.CurrentState.Version = $Release.Id

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerUrl
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

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
