$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['VooVMeeting1'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['VooVMeeting1'] = $OldReleases = [ordered]@{}
}

# x86
$Object1 = Invoke-RestMethod -Uri 'https://voovmeeting.com/web-service/query-download-info?q=[{"package-type":"app","channel":"1410000197","platform":"windows","decorators":["intl"]}]&nonce=AAAAAAAAAAAAAAAA'
# x64
# $Object2 = Invoke-RestMethod -Uri 'https://voovmeeting.com/web-service/query-download-info?q=[{"package-type":"app","channel":"1410000197","platform":"windows","decorators":["intl"],"arch":"x86_64"}]&nonce=AAAAAAAAAAAAAAAA'

# if ($Object1.'info-list'[0].version -ne $Object2.'info-list'[0].version) {
#   $this.Log("Inconsistent versions: x86: $($Object1.'info-list'[0].version), x64: $($Object2.'info-list'[0].version)", 'Error')
#   return
# }

# Version
$this.CurrentState.Version = $Object1.'info-list'[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $InstallerUrl = $Object1.'info-list'[0].url.Replace('.officialwebsite', '')
}
# $this.CurrentState.Installer += [ordered]@{
#   Architecture = 'x64'
#   InstallerUrl = $InstallerUrlX64 = $Object2.'info-list'[0].url.Replace('.officialwebsite', '')
# }

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.'info-list'[0].'sub-date' | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      InstallerUrl    = $InstallerUrl
      # InstallerUrlX64 = $InstallerUrlX64
      ReleaseTime     = $this.CurrentState.ReleaseTime
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
