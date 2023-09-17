$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://www.openoffice.org/download/index.html')

$Prefix1 = $EdgeDriver.ExecuteScript('return DL.SF', $null)
$Prefix2 = $EdgeDriver.ExecuteScript('return DL.ASF_DIST', $null)
$Lang = $EdgeDriver.ExecuteScript('return DL.REL_FULL_LANG', $null)

# Version
$Version = $EdgeDriver.ExecuteScript('return DL.VERSION', $null)
$Build = $EdgeDriver.ExecuteScript('return DL.BUILD', $null)
$Task.CurrentState.Version = [regex]::Replace($Version, '(\d+)\.(\d+)\.(\d+)', '$1.$2$3') + '.' + $Build

# Installer
$Task.CurrentState.Installer += [ordered]@{
  InstallerUrl       = "${Prefix1}${Version}/binaries/en-US/Apache_OpenOffice_${Version}_Win_x86_install_en-US.exe/download"
  InstallerSha256Url = "${Prefix2}${Version}/binaries/en-US/Apache_OpenOffice_${Version}_Win_x86_install_en-US.exe.sha256"
}
$Task.CurrentState.Installer += $Lang | Where-Object -FilterScript { $_ -ne 'en-US' } | ForEach-Object -Process {
  [ordered]@{
    InstallerLocale    = $_
    InstallerUrl       = "${Prefix1}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe/download"
    InstallerSha256Url = "${Prefix2}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe.sha256"
  }
}

# ReleaseTime
$Task.CurrentState.ReleaseTime = $EdgeDriver.ExecuteScript('return DL.REL_DATE', $null) | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotesUrl
$Task.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = $EdgeDriver.ExecuteScript("return l10n['dl_rel_notes_aoo$($Version.Replace('.', ''))_link']", $null)
}

switch (Compare-State) {
  ({ $_ -ge 1 }) {
    $Task.CurrentState.Installer | ForEach-Object -Process {
      $_.InstallerSha256 = (Invoke-RestMethod -Uri $_.InstallerSha256Url).Split()[0].ToUpper()
    }

    $Object = Invoke-WebRequest -Uri $ReleaseNotesUrl | ConvertFrom-Html

    try {
      $ReleaseNotesTitleNode = $Object.SelectSingleNode('//div[@id="main-content"]/h2[contains(@id, "GeneralRemarks")]')
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = @()
        for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node.Name -ne 'h2'; $Node = $Node.NextSibling) {
          $ReleaseNotesNodes += $Node
        }
        # ReleaseNotes (en-US)
        $Task.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        Write-Host -Object "Task $($Task.Name): No ReleaseNotes for version $($Task.CurrentState.Version)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host -Object "Task $($Task.Name): ${_}" -ForegroundColor Yellow
    }

    Write-State
  }
  ({ $_ -ge 2 }) {
    Send-VersionMessage
  }
  ({ $_ -ge 3 }) {
    New-Manifest
  }
}
