$Object1 = Invoke-WebRequest -Uri 'https://www.ok2kkw.com/vusc4win_eng.htm'
$Object2 = $Object1 | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match($Object2.InnerText, 'VUSC(?:\s|&nbsp;)+4(?:\s|&nbsp;)+WIN(?:\s|&nbsp;)+(\d+(?:\.\d+)+)').Groups[1].Value

$Prefix = 'https://www.ok2kkw.com/vusc/vusc4win/'
$Object3 = Invoke-WebRequest -Uri "${Prefix}?C=N;O=D;V=1;F=0;P=*.zip"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = Join-Uri $Prefix $Object3.Links.Where({ try { $_.href -match 'vusc' -and $_.href -match 'setup' -and $_.href.Contains($this.CurrentState.Version.Replace('.', '')) } catch {} }, 'First')[0].href
  InstallationMetadata = [ordered]@{
    DefaultInstallLocation = '%HOMEDRIVE%\VUSC'
    Files                  = @(
      [ordered]@{
        RelativeFilePath = 'VUSC.exe'
        FileType         = 'launch'
      }
    )
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.Links.Where({ try { $_.href.Contains('news') } catch {} }, 'First')[0].href
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $this.CurrentState.Installer[0]['NestedInstallerFiles'] = @(7z.exe l -ba -slt $InstallerFile '*.exe' | Where-Object -FilterScript { $_ -match '^Path = ' } | ForEach-Object -Process { [ordered]@{ RelativeFilePath = [regex]::Match($_, '^Path = (.+)').Groups[1].Value } } | Select-Object -First 1)
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath -Resolve
    # InstallationMetadata > Files > FileSha256
    Start-ThreadJob -ScriptBlock { Start-Process -FilePath $using:InstallerFile2 -ArgumentList '/SP-', '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART' -Wait } | Wait-Job -Timeout 300 | Receive-Job | Out-Host
    $FileSha256 = (Get-FileHash -Path (Join-Path $Env:HOMEDRIVE 'VUSC' 'VUSC.exe') -Algorithm SHA256).Hash
    $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallationMetadata.Files[0]['FileSha256'] = $FileSha256 }

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
