$Object1 = Invoke-WebRequest -Uri 'https://zoom.us/releasenotes' -Method Post -UserAgent 'Mozilla/5.0 (ZOOM.Win 10.0 x64)' -Form @{
  os           = 'win7'
  type         = 'manual'
  upgrade64Bit = 1
} | ConvertFrom-ProtoBuf
$Object2 = $Object1['12'].Split(';') | ConvertFrom-StringData

# Version
$this.CurrentState.Version = $Object2.'Real-version'
$DisplayVersion = $Object2.'Display-version'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x86'
  InstallerType          = 'exe'
  InstallerUrl           = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomInstallerFull.exe"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      Publisher      = 'Zoom Video Communications, Inc.'
      DisplayVersion = $DisplayVersion
      ProductCode    = 'ZoomUMX'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerType          = 'exe'
  InstallerUrl           = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomInstallerFull.exe?archType=x64"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      Publisher      = 'Zoom Video Communications, Inc.'
      DisplayVersion = $DisplayVersion
      ProductCode    = 'ZoomUMX'
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'arm64'
  InstallerType          = 'exe'
  InstallerUrl           = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomInstallerFull.exe?archType=winarm64"
  AppsAndFeaturesEntries = @(
    [ordered]@{
      Publisher      = 'Zoom Video Communications, Inc.'
      DisplayVersion = $DisplayVersion
      ProductCode    = 'ZoomUMX'
    }
  )
}
$this.CurrentState.Installer += $InstallerMsiX86 = [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'msi'
  InstallerUrl  = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomInstallerFull.msi"
}
$this.CurrentState.Installer += $InstallerMsiX64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'msi'
  InstallerUrl  = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomInstallerFull.msi?archType=x64"
}
$this.CurrentState.Installer += $InstallerMsiArm64 = [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'msi'
  InstallerUrl  = "https://zoom.us/client/$($this.CurrentState.Version)/ZoomInstallerFull.msi?archType=winarm64"
}

$ReleaseNotesObject = ($Object1['11'] -split '(?=Release notes of \d+\.\d+\.\d+ \(\d+\))').Where({ $_.Contains($DisplayVersion) }, 'First')[0]
if ($ReleaseNotesObject) {
  # ReleaseNotes (en-US)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'en-US'
    Key    = 'ReleaseNotes'
    Value  = $ReleaseNotesObject -creplace 'Release notes of \d+\.\d+\.\d+ \(\d+\)' | Format-Text
  }
} else {
  $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # AppsAndFeaturesEntries
    $InstallerFileMsiX86 = Get-TempFile -Uri $InstallerMsiX86.InstallerUrl
    $InstallerFileMsiX64 = Get-TempFile -Uri $InstallerMsiX64.InstallerUrl
    $InstallerFileMsiArm64 = Get-TempFile -Uri $InstallerMsiArm64.InstallerUrl

    $RealVersion = $InstallerFileMsiX64 | Read-ProductVersionFromMsi

    $InstallerMsiX86['InstallerSha256'] = (Get-FileHash -Path $InstallerFileMsiX86 -Algorithm SHA256).Hash
    $InstallerMsiX86['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = 'Zoom (32-bit)'
        DisplayVersion = $RealVersion
        ProductCode    = $InstallerMsiX86['ProductCode'] = $InstallerFileMsiX86 | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerFileMsiX86 | Read-UpgradeCodeFromMsi
      }
    )

    $InstallerMsiX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileMsiX64 -Algorithm SHA256).Hash
    $InstallerMsiX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = 'Zoom (64-bit)'
        DisplayVersion = $RealVersion
        ProductCode    = $InstallerMsiX64['ProductCode'] = $InstallerFileMsiX64 | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerFileMsiX64 | Read-UpgradeCodeFromMsi
      }
    )

    $InstallerMsiArm64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileMsiArm64 -Algorithm SHA256).Hash
    $InstallerMsiArm64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayName    = 'Zoom (ARM64)'
        DisplayVersion = $RealVersion
        ProductCode    = $InstallerMsiArm64['ProductCode'] = $InstallerFileMsiArm64 | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerFileMsiArm64 | Read-UpgradeCodeFromMsi
      }
    )

    $this.Write()
  }
  'Changed|Updated' {
    $this.Print()
    $this.Message()
  }
  'Updated' {
    $this.Submit()
  }
}
