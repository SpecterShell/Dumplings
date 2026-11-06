$Object1 = Invoke-RestMethod -Uri 'https://dl.lazycatmicroserver.com/client/desktop/lzc-client-desktop.exe.metadata.json'

if ([string]::IsNullOrWhiteSpace($Object1.buildVersion)) {
  $this.Log('The feed returned an invalid response', 'Warning')
  return
}

# Version
$this.CurrentState.Version = $Object1.buildVersion -replace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'nullsoft'
  InstallerUrl  = "https://dl.lazycatmicroserver.com/client/desktop/stable/lzc-client-desktop_$($Object1.buildVersion).exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseNotes (zh-CN)
      $ReleaseNotesNode = $Object1.changelogs.Where({ $_.language -eq 'zh' }, 'First')
      if ($ReleaseNotesNode.changelog) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.changelog -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ConvertTo-UnorderedList | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotes (en-US)
      $ReleaseNotesNode = $Object1.changelogs.Where({ $_.language -eq 'en' }, 'First')
      if ($ReleaseNotesNode.changelog) {
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNode.changelog -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ConvertTo-UnorderedList | Format-Text
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
