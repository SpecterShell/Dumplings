$Object1 = Invoke-RestMethod -Uri 'https://appsupport.moonshot.cn/api/startup' -Method Post -Headers @{
  'x-msh-platform' = 'windows'
} -Body '{}' -ContentType 'application/json'

# Version
$this.CurrentState.Version = $Object1.upgrade.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.upgrade.apk_url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.upgrade.upgrade_dialog.content | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $NestedInstallerFileRoot = New-TempFolder
    7z.exe e -aoa -ba -bd '-t#' -o"${NestedInstallerFileRoot}" $InstallerFile '2.msi' | Out-Host
    $NestedInstallerFile = Join-Path $NestedInstallerFileRoot '2.msi'

    # InstallerSha256
    $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # AppsAndFeaturesEntries
    $this.CurrentState.Installer[0]['AppsAndFeaturesEntries'] = @(
      [ordered]@{
        ProductCode   = $this.CurrentState.Installer[0]['ProductCode'] = $NestedInstallerFile | Read-ProductCodeFromMsi
        UpgradeCode   = $NestedInstallerFile | Read-UpgradeCodeFromMsi
        InstallerType = 'wix'
      }
    )

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
