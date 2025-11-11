$EdgeDriver = Get-EdgeDriver -Headless
$EdgeDriver.Navigate().GoToUrl('https://www.openoffice.org/index.html')

# $Prefix1 = $EdgeDriver.ExecuteScript('return DL.SF', $null)
$Prefix2 = $EdgeDriver.ExecuteScript('return DL.ASF_DIST', $null)
$Lang = $EdgeDriver.ExecuteScript('return DL.REL_FULL_LANG', $null)

# Version
$Version = $EdgeDriver.ExecuteScript('return DL.VERSION', $null)
$Build = $EdgeDriver.ExecuteScript('return DL.BUILD', $null)
$this.CurrentState.Version = [regex]::Replace($Version, '(\d+)\.(\d+)\.(\d+)', '$1.$2$3') + '.' + $Build

# Installer
# $this.CurrentState.Installer += [ordered]@{
#   InstallerUrl       = "${Prefix2}${Version}/binaries/en-US/Apache_OpenOffice_${Version}_Win_x86_install_en-US.exe"
#   InstallerSha256Url = "${Prefix2}${Version}/binaries/en-US/Apache_OpenOffice_${Version}_Win_x86_install_en-US.exe.sha256"
# }
switch ($Lang) {
  # # en-US is the default locale of the manifests but not listed at the beginning of the list. Add en-US locale explicitly and skip it in this process
  # 'en-US' { continue }
  # The language-only locales gd and sr are not supported by WinGet client
  'ast' {
    $this.CurrentState.Installer += [ordered]@{
      InstallerLocale    = 'ast-ES'
      InstallerUrl       = "${Prefix2}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe"
      InstallerSha256Url = "${Prefix2}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe.sha256"
    }
    continue
  }
  'gd' {
    $this.CurrentState.Installer += [ordered]@{
      InstallerLocale    = 'gd-GB'
      InstallerUrl       = "${Prefix2}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe"
      InstallerSha256Url = "${Prefix2}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe.sha256"
    }
    continue
  }
  'sr' {
    $this.CurrentState.Installer += [ordered]@{
      InstallerLocale    = 'sr-Cyrl'
      InstallerUrl       = "${Prefix2}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe"
      InstallerSha256Url = "${Prefix2}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe.sha256"
    }
    $this.CurrentState.Installer += [ordered]@{
      InstallerLocale    = 'sr-Latn'
      InstallerUrl       = "${Prefix2}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe"
      InstallerSha256Url = "${Prefix2}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe.sha256"
    }
    continue
  }
  Default {
    $this.CurrentState.Installer += [ordered]@{
      InstallerLocale    = $_
      InstallerUrl       = "${Prefix2}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe"
      InstallerSha256Url = "${Prefix2}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe.sha256"
    }
    continue
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $EdgeDriver.ExecuteScript('return DL.REL_DATE', $null) | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = $EdgeDriver.ExecuteScript("return l10n['dl_rel_notes_aoo$($Version.Replace('.', ''))_link']", $null)
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.CurrentState.Installer | ForEach-Object -Process {
      $_.InstallerSha256 = (Invoke-RestMethod -Uri $_.InstallerSha256Url).Split()[0].ToUpper()
      $_.Remove('InstallerSha256Url')
    }

    try {
      $Object1 = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object1.SelectSingleNode('//div[@id="main-content"]/h2[contains(@id, "GeneralRemarks")]')
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
