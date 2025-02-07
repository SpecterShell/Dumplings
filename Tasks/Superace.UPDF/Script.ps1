function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'UPDF.exe' | Out-Host

  # Version
  $this.CurrentState.Version = Join-Path $InstallerFileExtracted 'UPDF.exe' | Read-ProductVersionFromExe
  # RealVersion
  $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
}

function Get-ReleaseNotes {
  $ShortVersion = $this.CurrentState.Version -replace '\.0+$', ''

  try {
    if ($Global:DumplingsStorage.Contains('UPDF') -and $Global:DumplingsStorage.UPDF.Contains($ShortVersion)) {
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Global:DumplingsStorage.UPDF.$ShortVersion.ReleaseNotes
      }
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Global:DumplingsStorage.UPDF.$ShortVersion.ReleaseNotesCN
      }
    } else {
      $this.Log("No ReleaseNotes (en-US) and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Global
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = 'https://download.updf.com/updf/basic/win/updf-9000000000-win-full.exe'
}
$Object1 = Invoke-WebRequest -Uri $Installer.InstallerUrl -Method Head
$ETag = $Object1.Headers.ETag[0]

# China
$this.CurrentState.Installer += $InstallerCN = [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = 'https://download.updf.cn/updf/basic/win/updf-8000000000-win-full.exe'
}
$Object2 = Invoke-WebRequest -Uri $InstallerCN.InstallerUrl -Method Head
$ETagCN = $Object2.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagCN = @($ETagCN)

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagCN = @($ETagCN)

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag is not changed
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (Global)", 'Info')
  return
}
if ($ETagCN -in $this.LastState.ETagCN) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (China)", 'Info')
  return
}

Read-Installer

# Case 3: The installer file has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

# Case 4: The ETag has changed, but the hash is not
if ($Installer.InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag has changed, but the hash is not', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag
  $this.CurrentState.ETagCN = $this.LastState.ETagCN + $ETagCN

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)
$this.CurrentState.ETagCN = @($ETagCN)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, the hash and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: Both the ETag and the hash have changed, but the version is not
  Default {
    $this.Log('The ETag and the hash have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
