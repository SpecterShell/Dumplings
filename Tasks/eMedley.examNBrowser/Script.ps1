$Object1 = Invoke-RestMethod -Uri 'https://he.emedley.com/common/legacy_provider/offline.php' -Method Post -Body (
  @{
    type   = 'windows'
    action = 'latest_browser_version'
  } | ConvertTo-Json -Compress
) -ContentType 'application/json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://he.emedley.com/gen/public/examn_v2/examn_browser/setup-x64.zip'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = 'https://he.emedley.com/gen/public/examn_v2/examn_browser/setup-arm64.zip'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.released_date | Get-Date -Format 'yyyy-MM-dd'
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFileX64 = Get-TempFile -Uri $InstallerX64.InstallerUrl
    $InstallerFileX64Extracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileX64Extracted}" $InstallerFileX64 'setup-x64.exe' | Out-Host
    $InstallerFileX642 = Join-Path $InstallerFileX64Extracted 'setup-x64.exe'
    # InstallerSha256
    $InstallerX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX64 -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFileX642 | Read-ProductVersionFromExe

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
