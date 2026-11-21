$Object1 = Invoke-RestMethod -Uri 'https://cdn.desktop.baimiaoapp.com/updater/update.json'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.name, 'v(.+)').Groups[1].Value

# Installer
if ($Object1.platforms.'windows-x86_64'.url.Contains('.msi')) {
  $this.CurrentState.Installer += [ordered]@{
    InstallerType        = 'zip'
    NestedInstallerType  = 'wix'
    InstallerUrl         = $Object1.platforms.'windows-x86_64'.url
    NestedInstallerFiles = @(
      [ordered]@{
        RelativeFilePath = "白描桌面版_$($this.CurrentState.Version)_x64_zh-CN.msi"
      }
    )
  }
} elseif ($Object1.platforms.'windows-x86_64'.url.Contains('.nsis')) {
  $this.CurrentState.Installer += [ordered]@{
    InstallerType        = 'zip'
    NestedInstallerType  = 'nullsoft'
    InstallerUrl         = Join-Uri $Object1.platforms.'windows-x86_64'.url 'baimiao_windows.zip'
    NestedInstallerFiles = @(
      [ordered]@{
        RelativeFilePath = "白描桌面版_$($this.CurrentState.Version)_x64_setup.exe"
      }
    )
  }
} else {
  $this.Log("Unknown installer type for version $($this.CurrentState.Version)", 'Error')
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.pub_date.ToUniversalTime()

      # ReleaseNotes (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'ReleaseNotes'
        Value  = $Object1.notes | Format-Text
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
      $Installer['NestedInstallerFiles'] = @(
        [ordered]@{
          RelativeFilePath = $ZipFile.Entries.Where({ $_.Name -match '\.(zip|exe)$' }, 'First')[0].FullName.Replace('/', '\')
        }
      )
      $ZipFile.Dispose()
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
