# x86
$Object1 = Invoke-RestMethod -Uri 'https://gate.roxybrowser.net/get_app_upgrade' -Method Post -Body (
  @{
    os        = 'win32'
    osVersion = '10'
    cpu       = 'intel'
    osBit     = '32'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'
$PrefixX86 = $Object1.data.downloadUrl
$Object2 = Invoke-RestMethod -Uri "${PrefixX86}/latest.yml" | ConvertFrom-Yaml

# x64
$Object3 = Invoke-RestMethod -Uri 'https://gate.roxybrowser.net/get_app_upgrade' -Method Post -Body (
  @{
    os        = 'win32'
    osVersion = '10'
    cpu       = 'intel'
    osBit     = '64'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'
$PrefixX64 = $Object3.data.downloadUrl
$Object4 = Invoke-RestMethod -Uri "${PrefixX64}/latest.yml" | ConvertFrom-Yaml

if ($Object2.version -ne $Object4.version) {
  $this.Log("x86 version: $($Object2.version)")
  $this.Log("x64 version: $($Object4.version)")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $Object4.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "${PrefixX86}/$($Object2.files[0].url)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${PrefixX64}/$($Object4.files[0].url)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2.releaseDate | Get-Date -AsUTC

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.data.upgradeContent | ConvertFrom-Html | Get-TextContent | Format-Text
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
