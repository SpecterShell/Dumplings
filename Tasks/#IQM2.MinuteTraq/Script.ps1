$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['MinuteTraq'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['MinuteTraq'] = $OldReleases = [ordered]@{}
}

# https://github.com/Hollow667/Site-Subdomains/blob/master/Domains/iqm2.com
$Object1 = Invoke-RestMethod -Uri 'https://alamancecountync.iqm2.com/MinuteTraqService/Data_1_0.asmx' -Method Post -Headers @{
  SOAPAction = 'MKDBWCF.ASDAuthService/IASDAuthService/ASDGetSoftwareList'
} -Body @'
<?xml version="1.0" encoding="utf-8"?>
<soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
  <soap12:Body>
    <GetClientUpdateInfo xmlns="http://tempuri.org/MinuteTraqService/Data_1_0" />
  </soap12:Body>
</soap12:Envelope>
'@ -ContentType 'application/soap+xml; charset=utf-8'
$Object2 = $Object1.Envelope.Body.GetClientUpdateInfoResponse.GetClientUpdateInfoResult.MinuteTraqUpdate

# Version
$this.CurrentState.Version = $Object2.VersionNum

# RealVersion
$this.CurrentState.RealVersion = $this.CurrentState.Version.Split('.')[0..2] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.DownloadURL
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = $Object2.VersionDate | Get-Date -Format 'yyyy-MM-dd'

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime = $this.CurrentState.ReleaseTime
    }
    if ($Global:DumplingsPreference.Contains('EnableWrite') -and $Global:DumplingsPreference.EnableWrite) {
      $OldReleases | ConvertTo-Yaml -OutFile $OldReleasesPath -Force
    }
  }
  'New' {
    $this.Print()
    $this.Write()
  }
  { $_ -match 'Changed' -and $_ -notmatch 'Updated|Rollbacked' } {
    $this.Print()
    $this.Write()
    $this.Message()
  }
  'Updated' {
    $this.Print()
    $this.Write()
    if (-not $OldReleases.Contains($this.CurrentState.Version)) {
      $this.Message()
    }
  }
  { $_ -match 'Rollbacked' -and -not $OldReleases.Contains($this.CurrentState.Version) } {
    $this.Print()
    $this.Message()
  }
}
