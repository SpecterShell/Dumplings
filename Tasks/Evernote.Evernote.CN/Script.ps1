$Object1 = Invoke-RestMethod -Uri 'https://update.yinxiang.com/public/YXWin6/update.xml'

# Version
$this.CurrentState.Version = ($Object1.update.release3.version -split '\s+')[0]

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.update.release3.executable.url | ConvertTo-Https
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $Object1.update.release3.releasenotes.Where({ $_.lang -eq 'en-us' }, 'First')[0].url
      }

      # ReleaseNotesUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotesUrl'
        Value  = $ReleaseNotesUrlCN = $Object1.update.release3.releasenotes.Where({ $_.lang -eq 'zh-CN' }, 'First')[0].url
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $NestedInstallerFileRoot = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${NestedInstallerFileRoot}" $InstallerFile '2.msi' | Out-Host
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

    try {
      $Object2 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object2.SelectNodes('/html/body/node()[contains(., "Welcome to")][1]/following-sibling::node()') | Get-TextContent | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object3 = Invoke-WebRequest -Uri $ReleaseNotesUrlCN | ConvertFrom-Html

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object3.SelectNodes('/html/body/node()[contains(., "欢迎体验")][1]/following-sibling::node()') | Get-TextContent | Format-Text
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
