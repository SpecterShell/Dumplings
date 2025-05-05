$Object1 = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/fxsound2/fxsound-app/HEAD/release/updates.txt' | ConvertFrom-Ini

# Version
$this.CurrentState.Version = $Object1.Update.ProductVersion

# Installer
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  InstallerUrl = "https://raw.githubusercontent.com/fxsound2/fxsound-app/refs/tags/v$($this.CurrentState.Version)/release/fxsound_setup.exe"
}
$this.CurrentState.Installer += $InstallerArm64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = "https://raw.githubusercontent.com/fxsound2/fxsound-app/refs/tags/v$($this.CurrentState.Version)/release/arm64/fxsound_setup.arm64.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$InstallerX64.InstallerUrl] = $InstallerX64File = Get-TempFile -Uri $InstallerX64.InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $InstallerX64FileExtracted = New-TempFolder
    Start-Process -FilePath $InstallerX64File -ArgumentList @('/extract', $InstallerX64FileExtracted) -Wait
    $InstallerX64File2 = Join-Path $InstallerX64FileExtracted 'fxsound.x64.msi'
    # ProductCode
    $InstallerX64['ProductCode'] = $InstallerX64File2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $InstallerX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerX64File2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerX64FileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    $this.InstallerFiles[$InstallerArm64.InstallerUrl] = $InstallerArm64File = Get-TempFile -Uri $InstallerArm64.InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $InstallerArm64FileExtracted = New-TempFolder
    Start-Process -FilePath $InstallerArm64File -ArgumentList @('/extract', $InstallerArm64FileExtracted) -Wait
    $InstallerArm64File2 = Join-Path $InstallerArm64FileExtracted 'fxsound.arm64.msi'
    # ProductCode
    $InstallerArm64['ProductCode'] = $InstallerArm64File2 | Read-ProductCodeFromMsi
    # AppsAndFeaturesEntries
    $InstallerArm64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        UpgradeCode   = $InstallerArm64File2 | Read-UpgradeCodeFromMsi
        InstallerType = 'msi'
      }
    )
    Remove-Item -Path $InstallerArm64FileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/fxsound2/fxsound-app/HEAD/release/changelog.txt').RawContentStream)

      while (-not $Object2.EndOfStream) {
        if ($Object2.ReadLine() -match "version $([regex]::Escape($this.CurrentState.Version))") {
          $null = $Object2.ReadLine()
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^version \d+(?:\.\d+)+') {
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
