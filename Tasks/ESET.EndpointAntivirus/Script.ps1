$Object1 = (Invoke-WebRequest -Uri 'https://gwc.eset.com/v1/product/22').Content | ConvertFrom-Json -AsHashtable
# x86
$Object2 = $Object1.files.installer.Values.Where({ $_.installer_type -eq 1 -and $_.av_remover -eq 'No' -and $_.os_group -eq '2626876' }, 'First')[0]
# x64
$Object3 = $Object1.files.installer.Values.Where({ $_.installer_type -eq 1 -and $_.av_remover -eq 'No' -and $_.os_group -eq '2626888' }, 'First')[0]
# arm64
$Object4 = $Object1.files.installer.Values.Where({ $_.installer_type -eq 1 -and $_.av_remover -eq 'No' -and $_.os_group -eq '2626895' }, 'First')[0]

if (@(@($Object2, $Object3, $Object4) | Sort-Object -Property { $_.full_version } -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x86: $($Object2.full_version), x64: $($Object3.full_version), arm64: $($Object4.full_version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object3.full_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.url.Replace('/latest/', "/v$($this.CurrentState.Version.Split('.')[0])/$($this.CurrentState.Version)/")
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object3.url.Replace('/latest/', "/v$($this.CurrentState.Version.Split('.')[0])/$($this.CurrentState.Version)/")
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object4.url.Replace('/latest/', "/v$($this.CurrentState.Version.Split('.')[0])/$($this.CurrentState.Version)/")
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $ReleaseNotesObject = $Object1.changelogs.Where({ $_.product_id -eq 22 }, 'First')[0].changelogs.'en_US' | ConvertFrom-Html
      $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
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
