# Version
$this.CurrentState.Version = $Global:DumplingsStorage.pConPlannerMetadata.'pCon.planner64'.GetEnumerator().Where({ $_.Value -eq 'Current' }, 'Last')[0].Name
$ShortVersion = $this.CurrentState.Version.Split('.')[0..1] -join '.'

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://downloads.pcon-solutions.com/pCon/planner/${ShortVersion}/pCon.planner_Std_setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = "https://docs.pcon-solutions.com/pCon/planner/${ShortVersion}/pCon.planner_${ShortVersion}_Features_EN.pdf"
      }

      # Documentations
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'Documentations'
        Value = @(
          [ordered]@{
            DocumentLabel = 'Shortcuts'
            DocumentUrl   = "https://docs.pcon-solutions.com/pCon/planner/${ShortVersion}/pCon.planner_${ShortVersion}_Shortcuts_EN.pdf"
          }
          [ordered]@{
            DocumentLabel = 'Editions'
            DocumentUrl   = "https://docs.pcon-solutions.com/pCon/planner/${ShortVersion}/pCon.planner_${ShortVersion}_Editions_EN.pdf"
          }
        )
      }

      # Documentations (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = '快捷键'
            DocumentUrl   = "https://docs.pcon-solutions.com/pCon/planner/${ShortVersion}/pCon.planner_${ShortVersion}_Shortcuts_EN.pdf"
          }
          [ordered]@{
            DocumentLabel = '版本'
            DocumentUrl   = "https://docs.pcon-solutions.com/pCon/planner/${ShortVersion}/pCon.planner_${ShortVersion}_Editions_EN.pdf"
          }
        )
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = $InstallerFile | Expand-InstallShield
      $InstallerFile2 = Get-ChildItem -Path $InstallerFileExtracted -Include '*.msi' -Recurse | Select-Object -First 1
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
      # AppsAndFeaturesEntries
      $Installer['AppsAndFeaturesEntries'] = @(
        [ordered]@{
          DisplayName   = $InstallerFile2 | Read-ProductNameFromMsi
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
