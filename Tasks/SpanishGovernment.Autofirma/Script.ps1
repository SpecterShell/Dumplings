$Object1 = Invoke-WebRequest -Uri 'https://administracionelectronica.gob.es/ctt/clienteafirma/descargas'

# EXE x86
$InstallerLink = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('AutoFirma') -and -not $_.href.Contains('MSI') -and $_.href.Contains('32') } catch {} }, 'First')[0]
$VersionEXEx86 = [regex]::Match($InstallerLink.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerType        = 'zip'
  NestedInstallerType  = 'nullsoft'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "AutoFirma_32_v$($VersionEXEx86.Replace('.', '_'))_installer.exe"
    }
  )
  InstallerUrl         = $InstallerLink.href
}
# EXE x64
$InstallerLink = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('AutoFirma') -and -not $_.href.Contains('MSI') -and $_.href.Contains('64') } catch {} }, 'First')[0]
$VersionEXEx64 = [regex]::Match($InstallerLink.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'nullsoft'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "AutoFirma_64_v$($VersionEXEx64.Replace('.', '_'))_installer.exe"
    }
  )
  InstallerUrl         = $InstallerLink.href
}
# MSI x86
$InstallerLink = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('AutoFirma') -and $_.href.Contains('MSI') -and $_.href.Contains('32') } catch {} }, 'First')[0]
$VersionMSIx86 = [regex]::Match($InstallerLink.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerType        = 'zip'
  NestedInstallerType  = 'wix'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "AutoFirma_32_v$($VersionMSIx86.Replace('.', '_'))_installer.msi"
    }
  )
  InstallerUrl         = $InstallerLink.href
}
# MSI x64
$InstallerLink = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('AutoFirma') -and $_.href.Contains('MSI') -and $_.href.Contains('64') } catch {} }, 'First')[0]
$VersionMSIx64 = [regex]::Match($InstallerLink.outerHTML, '(\d+(?:\.\d+)+)').Groups[1].Value
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerType        = 'zip'
  NestedInstallerType  = 'wix'
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "AutoFirma_64_v$($VersionMSIx64.Replace('.', '_'))_installer.msi"
    }
  )
  InstallerUrl         = $InstallerLink.href
}

if (@(@($VersionEXEx86, $VersionEXEx64, $VersionMSIx86, $VersionMSIx64) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: EXE x86: ${VersionEXEx86}, EXE x64: ${VersionEXEx64}, MSI x86: ${VersionMSIx86}, MSI x64: ${VersionMSIx64}", 'Error')
  return
}

# Version
$this.CurrentState.Version = $VersionEXEx64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://administracionelectronica.gob.es/ctt/resources/Soluciones/138/Descargas/AF-whatsnew-ES.txt').RawContentStream)

      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String -match "^AutoFirma v$([regex]::Escape($this.CurrentState.Version))") {
          $null = $Object2.ReadLine()
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^AutoFirma v\d+(\.\d+)+') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (es-ES)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'es-ES'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (es-ES) for version $($this.CurrentState.Version)", 'Warning')
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
