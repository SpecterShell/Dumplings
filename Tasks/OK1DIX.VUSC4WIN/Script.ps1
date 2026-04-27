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

    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl | Rename-Item -NewName { "${_}.zip" } -PassThru | Select-Object -ExpandProperty 'FullName'
    $InstallerFileExtracted = New-TempFolder
    Expand-Archive -Path $InstallerFile -DestinationPath $InstallerFileExtracted -Force
    $InstallerFile2 = Get-ChildItem -Path $InstallerFileExtracted -Filter '*.exe' -Recurse | Select-Object -First 1 -ExpandProperty 'FullName'
    $this.CurrentState.Installer[0]['NestedInstallerFiles'] = @(
      [ordered]@{
        RelativeFilePath = [System.IO.Path]::GetRelativePath($InstallerFileExtracted, $InstallerFile2)
      }
    )
    $InstallerFile2Extracted = New-TempFolder
    # InstallationMetadata > Files > FileSha256
    $InstallerFile3 = Expand-InnoInstaller -Path $InstallerFile2 -DestinationPath $InstallerFile2Extracted -Name 'VUSC.exe' -Language 'en' | Select-Object -First 1 -ExpandProperty 'FullName'
    $FileSha256 = (Get-FileHash -Path $InstallerFile3 -Algorithm SHA256).Hash
    $this.CurrentState.Installer | ForEach-Object -Process { $_.InstallationMetadata.Files[0]['FileSha256'] = $FileSha256 }
    Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
