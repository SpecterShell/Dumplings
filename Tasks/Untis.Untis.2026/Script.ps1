function Get-ReleaseNotes {
  try {
    $Object4 = Invoke-WebRequest -Uri 'https://www.untis.at/fileadmin/downloads/2026/releasenotes.html' | ConvertFrom-Html

    $ReleaseNotesTitleNode = $Object4.SelectSingleNode("//h2[contains(., '$($this.CurrentState.Version.Split('.')[0..2] -join '.')')]")
    if ($ReleaseNotesTitleNode) {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact([regex]::Match($ReleaseNotesTitleNode.InnerText, '(\d{1,2}\.\d{1,2}\.20\d{2})').Groups[1].Value, [string[]]@('dd.MM.yyyy', 'd.M.yyyy'), $null).ToString('yyyy-MM-dd')

      # ReleaseNotes (de-AT)
      $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'de-AT'
        Key    = 'ReleaseNotes'
        Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
      }
    } else {
      $this.Log("No ReleaseNotes (de-AT) for version $($this.CurrentState.Version)", 'Warning')
    }
  } catch {
    $_ | Out-Host
    $this.Log($_, 'Warning')
  }
}

# x86
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = 'https://www.untis.at/fileadmin/downloads/2026/SetupUntis2026.exe'
}

# x64
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = 'https://www.untis.at/fileadmin/downloads/2026/SetupUntis2026-x64.exe'
}

$Result = $this.CheckInstallerUpdates(@{
  Validator = 'LastModified'
  Installers = @(
    @{ InstallerIndex = 0; LegacyState = @{ ValidatorField = 'LastModified'; InstallerIndex = 0 } }
    @{ InstallerIndex = 1; LegacyState = @{ ValidatorField = 'LastModifiedX64'; InstallerIndex = 1 } }
  )
  ReadVersion = {
    param($Path)
    $Version = (Read-ProductVersionRawFromExe -Path $Path).ToString()
    @{ Version = $Version; RealVersion = $Version.Split('.')[0] }
  }
})
if ($Result.NeedsMetadata) { Get-ReleaseNotes }
$this.CompleteInstallerUpdates($Result)
