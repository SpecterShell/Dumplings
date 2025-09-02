function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'FolderSizeExplorer.msi' 'ReleaseNotes.txt' | Out-Host
  $InstallerFile2 = Join-Path $InstallerFileExtracted 'FolderSizeExplorer.msi'
  # Version
  $this.CurrentState.Version = $InstallerFile2 | Read-ProductVersionFromMsi
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  # ProductCode
  $this.CurrentState.Installer[0]['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
  # AppsAndFeaturesEntries
  $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
    [ordered]@{
      UpgradeCode = $InstallerFile2 | Read-UpgradeCodeFromMsi
    }
  )

  try {
    $InstallerFile3 = (Get-Item -Path (Join-Path $InstallerFileExtracted 'ReleaseNotes.txt')).FullName
    $Object2 = [System.IO.File]::OpenRead($InstallerFile3)
    $Object3 = [System.IO.StreamReader]::new($Object2)

    while (-not $Object3.EndOfStream) {
      $String = $Object3.ReadLine()
      if ($String -match "Version $([regex]::Escape($this.CurrentState.Version))") {
        if ($String -match '(\d{1,2}-[a-zA-Z]+-20\d{2})') {
          $this.CurrentState.ReleaseTime = $Matches[1] | Get-Date -Format 'yyyy-MM-dd'
        } else {
          $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
        }
        $null = $Object3.ReadLine()
        break
      }
    }
    if (-not $Object3.EndOfStream) {
      $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
      while (-not $Object3.EndOfStream) {
        $String = $Object3.ReadLine()
        if ($String -notmatch 'Version \d+(\.\d+)+') {
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
      $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
    }

    $Object3.Close()
    $Object2.Close()
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }

  Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrl -Uri 'https://www.folder-size-explorer.com/download-fse.php'
}

$Object1 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# Hash
$this.CurrentState.Hash = $Object1.Headers.'x-goog-hash'.Where({ $_.StartsWith('md5=') }, 'First')[0] -replace '^md5='

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

# Case 2: The hash is unchanged
if ($this.CurrentState.Hash -eq $this.LastState.Hash) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

switch -Regex ($this.Check()) {
  # Case 5: The hash and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 4: The hash has changed, but the version is not
  # The installer might be updated without changing the version (e.g., virus database update)
  # Force submit the manifest even if neither the version nor the installer has changed
  default {
    $this.Log('The hash has changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
