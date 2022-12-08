# Download
$Object1 = Invoke-RestMethod -Uri 'https://player-update.coldlake1.com/version/info' | Get-EmbeddedJson -StartsFrom 'getVersionInfo(' | ConvertFrom-Json
# Upgrade x64
$Object2 = Invoke-RestMethod -Uri 'https://ab.coldlake1.com/v1/abt/matcher?arch=x64'
# Upgrade x86
$Object3 = Invoke-RestMethod -Uri 'https://ab.coldlake1.com/v1/abt/matcher?arch=x86'

if ((Compare-Version -ReferenceVersion $Object1.data.official.x64.full.version -DifferenceVersion ([regex]::Match($Object2.data, '(\d{14})').Groups[1].Value)) -gt 0) {
  if ($Object2.data -ne $Object3.data) {
    Write-Host -Object "Task $($Task.Name): The versions are different between the architectures"
    $Task.Config.Notes = '各个架构的版本号不相同'
  } else {
    $Identical = $True
  }

  # Version
  $Task.CurrentState.Version = [regex]::Match($Object2.data, '(\d{14})').Groups[1].Value

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = "https://player-download.coldlake1.com/player/$($Task.CurrentState.Version)/Stellar_$($Task.CurrentState.Version)_official_stable_full_x86.exe"
  }
  $Task.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = "https://player-download.coldlake1.com/player/$($Task.CurrentState.Version)/Stellar_$($Task.CurrentState.Version)_official_stable_full_x64.exe"
  }
} else {
  if ($Object1.data.official.x64.full.version -ne $Object1.data.official.x86.full.version) {
    Write-Host -Object "Task $($Task.Name): The versions are different between the architectures"
    $Task.Config.Notes = '各个架构的版本号不相同'
  } else {
    $Identical = $True
  }

  # Version
  $Task.CurrentState.Version = $Object1.data.official.x64.full.version

  # Installer
  $Task.CurrentState.Installer += [ordered]@{
    Architecture = 'x86'
    InstallerUrl = $Object1.data.official.x86.full.url
  }
  $Task.CurrentState.Installer += [ordered]@{
    Architecture = 'x64'
    InstallerUrl = $Object1.data.official.x64.full.url
  }
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    # RealVersion
    $Task.CurrentState.RealVersion = Get-TempFile -Uri $Task.CurrentState.Installer[0].InstallerUrl | Read-ProductVersionFromExe

    $Object4 = Invoke-WebRequest -Uri "https://player-update.coldlake1.com/version/gray/$($Task.CurrentState.Version)_x64.ini" | Read-ResponseContent | ConvertFrom-Ini

    try {
      # ReleaseNotes (zh-CN)
      $Task.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object4.update.info | Format-Text
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 -and $Identical }) {
    New-Manifest
  }
}
