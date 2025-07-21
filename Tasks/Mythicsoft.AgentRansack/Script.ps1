$Object1 = Invoke-RestMethod -Uri 'https://account.mythicsoft.com/getversion.aspx?productid=1&afterversion=0&infotype=1&features=0'

# Version
$this.CurrentState.Version = [regex]::Match($Object1.versions.version[0].ds, 'Build (\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = "https://download.mythicsoft.com/flp/$($this.CurrentState.Version)/agentransack_x86_msi_$($this.CurrentState.Version).zip"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "agentransack_x86_$($this.CurrentState.Version).msi"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = "https://download.mythicsoft.com/flp/$($this.CurrentState.Version)/agentransack_x64_msi_$($this.CurrentState.Version).zip"
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "agentransack_x64_$($this.CurrentState.Version).msi"
    }
  )
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromMsi
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::new(1601, 1, 1).AddTicks([long]$Object1.versions.version[0].date).ToString('yyyy-MM-dd')

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.versions.version[0].'#text'.Replace('!br!', "`n") | Format-Text
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
