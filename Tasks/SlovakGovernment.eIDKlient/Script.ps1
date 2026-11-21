function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # RealVersion
  $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromMsi
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
}

function Get-ReleaseNotes {
  try {
    $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://eidas.minv.sk/download/files/windows/x64/eID_klient_release_notes.txt').RawContentStream)

    while (-not $Object2.EndOfStream) {
      $String = $Object2.ReadLine()
      if ($String -match "verzia $([regex]::Escape($this.CurrentState.Version))") {
        $null = $Object2.ReadLine()
        break
      }
    }
    if (-not $Object2.EndOfStream) {
      $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String -match 'Dátum sprístupnenia verzie: (\d{1,2}\W+\d{1,2}\W+20\d{2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = [datetime]::ParseExact($Matches[1], 'dd.MM.yyyy', $null).ToString('yyyy-MM-dd')
        } elseif ($String -notmatch 'Kontrolný odtlačok inštalačného balíka') {
          $ReleaseNotesObjects.Add($String)
        } else {
          break
        }
      }
      # ReleaseNotes (sk-SK)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'sk-SK'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesObjects | Format-Text
      }
    } else {
      $this.Log("No ReleaseTime and ReleaseNotes (sk-SK) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = 'https://eidas.minv.sk/downloadservice/eidklient/windows/eID_klient.msi'
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = 'https://eidas.minv.sk/download/files/windows/x64/eID_klient.msi'
}

# Content Length
$this.CurrentState.ContentLengthX86 = (Invoke-WebRequest -Uri $InstallerX86.InstallerUrl -Method Head).Headers.'Content-Length'[0]
$this.CurrentState.ContentLengthX64 = (Invoke-WebRequest -Uri $InstallerX64.InstallerUrl -Method Head).Headers.'Content-Length'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  return
}

# Case 2: The Content Length is unchanged
if ($this.CurrentState.ContentLengthX86 -eq $this.LastState.ContentLengthX86) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (x86)", 'Info')
  return
}
if ($this.CurrentState.ContentLengthX64 -eq $this.LastState.ContentLengthX64) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (x64)", 'Info')
  return
}

Read-Installer

switch -Regex ($this.Check()) {
  # Case 4: The Content Length and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 3: The Content Length has changed, but the version is not
  default {
    $this.Log('The Content Length and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
