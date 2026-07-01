function Read-Installer {
  $Script:InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-FileVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
}

function Get-ReleaseNotes {
  try {
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'history.txt' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'history.txt'
    $Object3 = [System.IO.StreamReader]::new($InstallerFile2)

    while (-not $Object3.EndOfStream) {
      $String = $Object3.ReadLine()
      if ($String.StartsWith($this.CurrentState.Version)) {
        break
      }
    }
    if (-not $Object3.EndOfStream) {
      $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
      while (-not $Object3.EndOfStream) {
        $String = $Object3.ReadLine()
        if ($String -match '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})') {
          # ReleaseTime
          $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
        } elseif ($String -notmatch '^\d+(?:\.\d+)+') {
          $ReleaseNotesObjects.Add($String)
        } else {
          break
        }
      }
      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesObjects | Format-Text
      }
    } else {
      $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }

  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  } finally {
    $Object3.Close()
    Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
  }
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Global:DumplingsStorage.IgneusPrefix $Global:DumplingsStorage.IgneusDownloadPage.Links.Where({ $_.href.EndsWith('.exe') -and $_.href -match 'Setup' -and $_.href -match 'SHC' }, 'First')[0].href
}

$ETag = (Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head).Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)

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

  Read-Installer
  Get-ReleaseNotes

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag is unchanged
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

Get-ReleaseNotes

# Case 4: The ETag has changed, but the SHA256 is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag has changed, but the SHA256 is not', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The ETag and the SHA256 have changed, but the version is not
  default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
