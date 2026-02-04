$OldReleasesPath = Join-Path $PSScriptRoot 'Releases.yaml'
if (Test-Path -Path $OldReleasesPath) {
  $Global:DumplingsStorage['YealinkUSBConnectCN'] = $OldReleases = Get-Content -Path $OldReleasesPath -Raw | ConvertFrom-Yaml -Ordered
} else {
  $Global:DumplingsStorage['YealinkUSBConnectCN'] = $OldReleases = [ordered]@{}
}

$Params = @{
  Uri         = 'https://update.ylcloud.com/yiot-manager/api/v1/external/software/checkVersion'
  Method      = 'Post'
  ContentType = 'application/json;charset=UTF-8'
  Body        = @{
    appId          = '72bbc75337eb4930ad93a5e13e5798d1'
    clientId       = 'H-YUC-00155d31bc02'
    clientType     = 'software'
    clientModel    = 'Yealink-USB-Connect'
    clientPlatform = 'windows'
  } | ConvertTo-Json -Compress
}
# en
$Object1 = Invoke-RestMethod @Params
# zh_CN
$Object2 = Invoke-RestMethod @Params -Headers @{ language = 'zh_CN' }

if ($Object1.data.version -ne $Object2.data.version) {
  $this.Log("Inconsistent versions: en: $($Object1.data.version), zh_CN: $($Object2.data.version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.data.file.url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    # ReleaseTime
    $this.CurrentState.ReleaseTime = $ReleaseTime = $Object1.data.releaseDate | Get-Date | ConvertTo-UtcDateTime -Id UTC

    # ReleaseNotes (en-US)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'en-US'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotes = $Object1.data.releaseNote | Format-Text
    }
    # ReleaseNotes (zh-CN)
    $this.CurrentState.Locale += [ordered]@{
      Locale = 'zh-CN'
      Key    = 'ReleaseNotes'
      Value  = $ReleaseNotesCN = $Object2.data.releaseNote | Format-Text
    }

    $OldReleases[$this.CurrentState.Version] = [ordered]@{
      ReleaseTime    = $ReleaseTime
      ReleaseNotes   = $ReleaseNotes
      ReleaseNotesCN = $ReleaseNotesCN
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
