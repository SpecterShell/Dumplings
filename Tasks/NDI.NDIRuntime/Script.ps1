# The Runtime & Tools are updated together, so we can check the same JSON as NDI Tools for the version number.
$Object1 = Invoke-RestMethod -Uri 'https://downloads.ndi.tv/Tools/ndi_tools_win_current_version.json'

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://downloads.ndi.tv/SDK/NDI_SDK/NDI $($this.CurrentState.Version.Split('.')[0]) Runtime.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = Invoke-WebRequest -Uri 'https://docs.ndi.video/all/using-ndi/ndi-tools/release-notes' | ConvertFrom-Html

      $VersionParts = $this.CurrentState.Version.Split('.')
      $VersionFull = $this.CurrentState.Version
      $VersionSimplified = $VersionFull -replace '(?:\.0)+$', ''
      $VersionMajor = if ($VersionParts.Length -ge 2) { "$($VersionParts[0]).$($VersionParts[1])" } else { $VersionParts[0] }
      $VersionCandidates = @($VersionFull, $VersionSimplified, $VersionMajor) | Where-Object { $_ } | Select-Object -Unique

      $ReleaseNotesTitleNode = $null
      foreach ($VersionCandidate in $VersionCandidates) {
        $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h2[@id='ndi-$VersionCandidate']")
        if ($ReleaseNotesTitleNode) {
          break
        }
      }

      if (-not $ReleaseNotesTitleNode) {
        $ReleaseNotesH2Nodes = $Object2.SelectNodes('//h2')
        foreach ($VersionCandidate in $VersionCandidates) {
          $VersionRegex = "^\s*NDI\s+$([regex]::Escape($VersionCandidate))\s*$"
          $ReleaseNotesTitleNode = $ReleaseNotesH2Nodes | Where-Object { $_.InnerText -match $VersionRegex } | Select-Object -First 1
          if ($ReleaseNotesTitleNode) {
            break
          }
        }
      }

      if ($ReleaseNotesTitleNode) {
        # Remove pseudo nodes
        $Object2.SelectNodes("//li/div[contains(.//@style, `"pseudoBefore`")]").ForEach({ $_.Remove() })

        # ReleaseNotes (en-US)
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h2'; $Node = $Node.NextSibling) { $Node }
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
