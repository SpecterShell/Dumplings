# x86 en-US
$Object1 = Invoke-RestMethod -Uri 'https://us.gate.roxybrowser.net/get_app_upgrade' -Method Post -Headers @{ language = 'en-US' } -Body (
  $Body = @{
    os        = 'win32'
    osVersion = '10'
    cpu       = 'intel'
    osBit     = '32'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'
# x86 zh-CN
$Object2 = Invoke-RestMethod -Uri 'https://us.gate.roxybrowser.net/get_app_upgrade' -Method Post -Headers @{ language = 'zh-CN' } -Body $Body -ContentType 'application/json'
# x64 en-US
$Object3 = Invoke-RestMethod -Uri 'https://us.gate.roxybrowser.net/get_app_upgrade' -Method Post -Headers @{ language = 'en-US' } -Body (
  $Body = @{
    os        = 'win32'
    osVersion = '10'
    cpu       = 'intel'
    osBit     = '64'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'
# x64 zh-CN
$Object4 = Invoke-RestMethod -Uri 'https://us.gate.roxybrowser.net/get_app_upgrade' -Method Post -Headers @{ language = 'zh-CN' } -Body $Body -ContentType 'application/json'

if (@(@($Object1, $Object2, $Object3, $Object4) | Sort-Object -Property { $_.data.version } -Unique).Count -gt 1) {
  $this.Log("x86 en-US version: $($Object1.data.version)")
  $this.Log("x86 zh-CN version: $($Object2.data.version)")
  $this.Log("x64 en-US version: $($Object3.data.version)")
  $this.Log("x64 zh-CN version: $($Object4.data.version)")
  throw 'Inconsistent versions detected'
}

$PrefixX86 = $Object1.data.downloadUrl
$Object5 = Invoke-RestMethod -Uri "${PrefixX86}/latest.yml" | ConvertFrom-Yaml

$PrefixX64 = $Object3.data.downloadUrl
$Object6 = Invoke-RestMethod -Uri "${PrefixX64}/latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object6.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "${PrefixX86}/$($Object5.files[0].url)"
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "${PrefixX64}/$($Object6.files[0].url)"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object6.releaseDate | Get-Date -AsUTC

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object3.data.upgradeContent | ConvertFrom-Html | Get-TextContent | Format-Text
      }

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object4.data.upgradeContent | ConvertFrom-Html | Get-TextContent | Format-Text
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
