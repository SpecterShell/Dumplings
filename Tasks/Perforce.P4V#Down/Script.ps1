$Object1 = Invoke-RestMethod -Uri 'https://portal.perforce.com/s/sfsites/aura?r=3&other.productDownload.getDownloadProductAndAllReleaeses=1' -Method Post -Body @{
  message        = @{
    actions = @(
      @{
        descriptor = 'apex://productDownloadController/ACTION$getDownloadProductAndAllReleaeses'
        params     = @{
          productName = 'Helix Visual Client (P4V)'
        }
        storable   = $true
      }
    )
  } | ConvertTo-Json -Depth 10
  'aura.context' = @{
    mode = 'PROD'
    app  = 'siteforce:communityApp'
  } | ConvertTo-Json -Depth 10
  'aura.token'   = 'null'
} -Headers @{ Origin = 'https://portal.perforce.com' }

# Installer
$this.CurrentState.Installer += $InstallerWiX = [ordered]@{
  InstallerType = 'wix'
  InstallerUrl  = $Object1.actions[0].returnValue.releases.Where({ $_.'Platform__c' -eq 'Windows (x64) (MSI)' -and $_.'current__c' }, 'First')[0].'Download_Link__c'
}
$VersionWiX = [regex]::Match($InstallerWiX.InstallerUrl, 'r(\d+(?:\.\d+)+)').Groups[1].Value

$this.CurrentState.Installer += $InstallerBurn = [ordered]@{
  InstallerType = 'burn'
  InstallerUrl  = $Object1.actions[0].returnValue.releases.Where({ $_.'Platform__c' -eq 'Windows (x64) (EXE)' -and $_.'current__c' }, 'First')[0].'Download_Link__c'
}
$VersionBurn = [regex]::Match($InstallerBurn.InstallerUrl, 'r(\d+(?:\.\d+)+)').Groups[1].Value

if ($VersionWiX -ne $VersionBurn) {
  $this.Log("Inconsistent versions detected: WiX: $VersionWiX, Burn: $VersionBurn", 'Warning')
}

# Version
$this.CurrentState.Version = $VersionWiX

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$InstallerWiX.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $InstallerWiX.InstallerUrl
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi

    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    $ToSubmit = $false

    $Mutex = [System.Threading.Mutex]::new($false, 'DumplingsSubmitLockP4V')
    $Mutex.WaitOne(30000) | Out-Null
    if (-not $Global:DumplingsStorage.Contains("P4V-$($this.CurrentState.Version)-ToSubmit")) {
      $Global:DumplingsStorage["P4V-$($this.CurrentState.Version)-ToSubmit"] = $ToSubmit = $true
    }
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()

    if ($ToSubmit) {
      $this.Submit()
    } else {
      $this.Log('Another task is submitting manifests for this package', 'Warning')
    }
  }
}
