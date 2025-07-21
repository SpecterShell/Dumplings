$Object1 = Invoke-RestMethod -Uri 'https://download-center.pcon-solutions.com/?feed=rss2&cat=20' | Where-Object -FilterScript { $_.title -match 'pCon\.basket \d+(?:\.\d+)+' } | Select-Object -First 1

# Version
$this.CurrentState.Version = [regex]::Match($Object1.title, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://downloads.pcon-solutions.com/pCon/basket/release/$($this.CurrentState.Version)/p-bk_$($this.CurrentState.Version)_32Bit_setup.zip"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://docs.pcon-solutions.com/pCon/basket/release/$($this.CurrentState.Version)/pCon.basket_Sales-History_$($this.CurrentState.Version)_en.pdf"
      }

      # Documentations
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'Documentations'
        Value = @(
          [ordered]@{
            DocumentLabel = 'User Guide'
            DocumentUrl   = "https://docs.pcon-solutions.com/pCon/basket/release/$($this.CurrentState.Version)/pCon.basket_$($this.CurrentState.Version)_Manual_en.pdf"
          }
          [ordered]@{
            DocumentLabel = 'Editions'
            DocumentUrl   = "https://docs.pcon-solutions.com/pCon/basket/release/$($this.CurrentState.Version)/pCon.basket_$($this.CurrentState.Version)_Editions_en.pdf"
          }
        )
      }

      # Documentations (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = '用户指南'
            DocumentUrl   = "https://docs.pcon-solutions.com/pCon/basket/release/$($this.CurrentState.Version)/pCon.basket_$($this.CurrentState.Version)_Manual_en.pdf"
          }
          [ordered]@{
            DocumentLabel = '版本'
            DocumentUrl   = "https://docs.pcon-solutions.com/pCon/basket/release/$($this.CurrentState.Version)/pCon.basket_$($this.CurrentState.Version)_Editions_en.pdf"
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
      7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'pCon.basket_setup.exe' | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted 'pCon.basket_setup.exe'
      $InstallerFile2Extracted = $InstallerFile2 | Expand-InstallShield
      $InstallerFile3 = Join-Path $InstallerFile2Extracted 'pCon.basket.msi'
      # RealVersion
      $this.CurrentState.RealVersion = $InstallerFile3 | Read-ProductVersionFromMsi
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile3 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          UpgradeCode   = $InstallerFile3 | Read-UpgradeCodeFromMsi
          InstallerType = 'msi'
        }
      )
      Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
