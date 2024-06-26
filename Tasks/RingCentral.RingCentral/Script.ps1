$Prefix = 'https://app.ringcentral.com/download/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | Read-ResponseContent | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'x64'
  InstallerType          = 'nullsoft'
  InstallerUrl           = $Prefix + $Object1.files[0].url
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $Object1.version
      ProductCode    = '584acf4c-ebc3-56fa-9cfd-586227f098ba'
    }
  )
}
$this.CurrentState.Installer += $InstallerWixX64 = [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = $Prefix + $Object1.files[0].url.Replace('.exe', '-x64.msi')
}
$this.CurrentState.Installer += [ordered]@{
  Architecture           = 'arm64'
  InstallerType          = 'nullsoft'
  InstallerUrl           = $Prefix + $Object1.files[0].url.Replace('.exe', '-arm64.exe')
  AppsAndFeaturesEntries = @(
    [ordered]@{
      DisplayVersion = $Object1.version
      ProductCode    = '584acf4c-ebc3-56fa-9cfd-586227f098ba'
    }
  )
}
$this.CurrentState.Installer += $InstallerWixARM64 = [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = $Prefix + $Object1.files[0].url.Replace('.exe', '-arm64.msi')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    # RealVersion + AppsAndFeaturesEntries
    $InstallerFileX64 = Get-TempFile -Uri $InstallerWixX64.InstallerUrl
    $InstallerWixX64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileX64 -Algorithm SHA256).Hash
    $InstallerWixX64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayVersion = $this.CurrentState.RealVersion = $InstallerFileX64 | Read-ProductVersionFromMsi
        ProductCode    = $InstallerWixX64['ProductCode'] = $InstallerFileX64 | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerFileX64 | Read-UpgradeCodeFromMsi
      }
    )

    $InstallerFileArm64 = Get-TempFile -Uri $InstallerWixARM64.InstallerUrl
    $InstallerWixARM64['InstallerSha256'] = (Get-FileHash -Path $InstallerFileArm64 -Algorithm SHA256).Hash
    $InstallerWixARM64['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        DisplayVersion = $InstallerFileArm64 | Read-ProductVersionFromMsi
        ProductCode    = $InstallerWixARM64['ProductCode'] = $InstallerFileArm64 | Read-ProductCodeFromMsi
        UpgradeCode    = $InstallerFileArm64 | Read-UpgradeCodeFromMsi
      }
    )

    try {
      $Object3 = Invoke-WebRequest -Uri 'https://support.ringcentral.com/release-notes/mvp/app/desktop-webapp.html' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object3.SelectSingleNode("//div[contains(@class, 'root')]//div[contains(@class, 'grid-item__parsys')]/div[contains(@class, 'custom-text') and contains(., 'Version $($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.SelectSingleNode('./following-sibling::*[2]'); $Node; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
