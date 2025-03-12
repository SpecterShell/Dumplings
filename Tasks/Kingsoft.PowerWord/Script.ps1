$Object1 = Invoke-RestMethod -Uri 'http://report2.iciba.com/report/pc/versionUpdate' -Body @{
  version = $this.LastState.Contains('Version') ? $this.LastState.Version : '2022.1.1.0141'
}

# Version
$this.CurrentState.Version = $Object1.data.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = 'https://download.iciba.com/pc/personal2016/PowerWord.800.12012.exe'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $WinGetInstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl

    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'setup.xml' | Out-Host
    $Object2 = Join-Path $InstallerFileExtracted 'setup.xml' | Get-Item | Get-Content -Raw
    $Object3 = $Object2 | ConvertFrom-Xml

    # PackageName
    $this.CurrentState.Locale += [ordered]@{
      Key   = 'PackageName'
      Value = [regex]::Match($Object2, '(金山词霸\d{4})').Groups[1].Value
    }
    # ProductCode
    $this.CurrentState.Installer[0]['ProductCode'] = "PowerWord$($Object3.config.office.info.version)"

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
