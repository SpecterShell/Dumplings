$Object1 = Invoke-RestMethod -Uri 'https://mkvtoolnix.download/releases.xml'

# Version
$this.CurrentState.Version = $Object1.'mkvtoolnix-releases'.release[0].version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://mkvtoolnix.download/windows/releases/$($this.CurrentState.Version)/mkvtoolnix-32-bit-$($this.CurrentState.Version)-setup.exe"
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://mkvtoolnix.download/windows/releases/$($this.CurrentState.Version)/mkvtoolnix-64-bit-$($this.CurrentState.Version)-setup.exe"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.'mkvtoolnix-releases'.release[0].date | Get-Date -Format 'yyyy-MM-dd'

      # ReleaseNotes (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'ReleaseNotes'
        Value  = $Object1.'mkvtoolnix-releases'.release[0].changes.change | ForEach-Object -Begin {
          [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
          $ReleaseNotesList = [ordered]@{}
        } -Process {
          $ReleaseNotesList[$_.type] = $ReleaseNotesList[$_.type] + @($_.'#text' | Convert-MarkdownToHtml | Get-TextContent)
        } -End {
          $ReleaseNotesList.GetEnumerator().ForEach({ "$($_.Name)`n$($_.Value | ConvertTo-UnorderedList)" }) -join "`n`n" | Format-Text
        }
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

    # InstallerSha256
    $Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile | Read-ProductVersionFromExe

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
