$Prefix = 'https://education.ti.com/en/software/details/en/B59F6C83468C4574ABFEE93D2BC3F807/swticonnectsoftware'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'en'
  InstallerUrl    = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href -match 'TI-Connect-\d+(?:\.\d+)+' } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'de'
  InstallerUrl    = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('DE') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'es'
  InstallerUrl    = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('ES') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'fr'
  InstallerUrl    = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('FR') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'it'
  InstallerUrl    = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('IT') } catch {} }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  InstallerLocale = 'pt'
  InstallerUrl    = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('PT') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # Documentations (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'Documentations'
        Value  = @(
          @{
            DocumentLabel = 'Guidebook'
            DocumentUrl   = $Object1.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('EN') -and -not $_.href.Contains('MAC') } catch {} }, 'First')[0].href
          }
        )
      }
      # Documentations (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = '指导手册'
            DocumentUrl   = $Object1.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('EN') -and -not $_.href.Contains('MAC') } catch {} }, 'First')[0].href
          }
        )
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.msi' | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted '2.msi'
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile2 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
