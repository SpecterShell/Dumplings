$EdgeDriver = Get-EdgeDriver
$EdgeDriver.Navigate().GoToUrl('https://www.openoffice.org/download/index.html')

$Prefix1 = $EdgeDriver.ExecuteScript('return DL.SF', $null)
$Prefix2 = $EdgeDriver.ExecuteScript('return DL.ASF_DIST', $null)
$Lang = $EdgeDriver.ExecuteScript('return DL.REL_FULL_LANG', $null)

# Version
$Version = $EdgeDriver.ExecuteScript('return DL.VERSION', $null)
$Build = $EdgeDriver.ExecuteScript('return DL.BUILD', $null)
$this.CurrentState.Version = [regex]::Replace($Version, '(\d+)\.(\d+)\.(\d+)', '$1.$2$3') + '.' + $Build

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl       = "${Prefix1}${Version}/binaries/en-US/Apache_OpenOffice_${Version}_Win_x86_install_en-US.exe/download"
  InstallerSha256Url = "${Prefix2}${Version}/binaries/en-US/Apache_OpenOffice_${Version}_Win_x86_install_en-US.exe.sha256"
}
$this.CurrentState.Installer += $Lang | Where-Object -FilterScript { $_ -ne 'en-US' } | ForEach-Object -Process {
  [ordered]@{
    InstallerLocale    = $_
    InstallerUrl       = "${Prefix1}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe/download"
    InstallerSha256Url = "${Prefix2}${Version}/binaries/${_}/Apache_OpenOffice_${Version}_Win_x86_install_${_}.exe.sha256"
  }
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $EdgeDriver.ExecuteScript('return DL.REL_DATE', $null) | Get-Date -Format 'yyyy-MM-dd'

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $ReleaseNotesUrl = $EdgeDriver.ExecuteScript("return l10n['dl_rel_notes_aoo$($Version.Replace('.', ''))_link']", $null)
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.CurrentState.Installer | ForEach-Object -Process {
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
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Logging("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $this.Logging($_, 'Warning')
    }

    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
