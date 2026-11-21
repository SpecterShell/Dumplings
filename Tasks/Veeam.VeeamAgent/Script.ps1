$Object1 = Invoke-RestMethod -Uri 'https://agents.butler.veeam.com/json-rpc.php' -Method Post -Body (
  @{
    id     = 1
    method = 'CheckForUpdates'
    params = @{
      ProductName = 'AgentWindows'
      Version     = $this.Status.Contains('New') ? '6.1.2.134' : $this.LastState.Version
    }
  } | ConvertTo-Json -Compress
)

if ($Object1.result.status -eq 'NoUpdates') {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$Object2 = $Object1.result.data | ConvertFrom-Base64 | ConvertFrom-Xml

# Version
$this.CurrentState.Version = $Object2.UpdateInfo.VeeamUpdates.AgentWindows.releaseFileVersion

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.UpdateInfo.VeeamUpdates.AgentWindows.Url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.UpdateInfo.issuetime | Get-Date -AsUTC

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.UpdateInfo.VeeamUpdates.AgentWindows.Description | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'Endpoint\Endpoint\Veeam_B&R_Endpoint_x64.msi' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'Veeam_B&R_Endpoint_x64.msi'
    # AppsAndFeaturesEntries + ProductCode
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
        UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $null
      }

      $Object3 = Invoke-RestMethod -Uri 'https://www.veeam.com/services/veeam/technical-documents?resourceType=resourcetype:techdoc/releasenotes&productId=41'
      $ReleaseNotesUrl = $Object3.payload.products.Where({ $_.productId -eq 41 }, 'First')[0].documentGroups.Where({ $_.resourceType -eq 'resourcetype:techdoc/releasenotes' }, 'First')[0].documents[0].links.html
      if ($ReleaseNotesUrl.Contains($this.CurrentState.Version.Split('.')[0..2] -join '_')) {
        # ReleaseNotesUrl
        $this.CurrentState.Locale += [ordered]@{
          Key   = 'ReleaseNotesUrl'
          Value = $Object3.payload.products.Where({ $_.productId -eq 41 }, 'First')[0].documentGroups.Where({ $_.resourceType -eq 'resourcetype:techdoc/releasenotes' }, 'First')[0].documents[0].links.html
        }
      } else {
        $this.Log("No ReleaseNotesUrl for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
