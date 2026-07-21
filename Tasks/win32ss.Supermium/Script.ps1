$RepoOwner = 'win32ss'
$RepoName = 'Supermium'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('_32') -and $_.name.Contains('setup') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += $Installer = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.exe') -and $_.name.Contains('_64') -and $_.name.Contains('setup') -and $_.name.Contains('win10_11') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        $ReleaseNotesObject = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak'
        # Remove hashes
        $ReleaseNotesObject.SelectNodes('//details[contains(./summary, "Hashes")]').ForEach({ $_.Remove() })
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObject | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl | Rename-Item -NewName { "${_}.exe" } -PassThru | Select-Object -ExpandProperty 'FullName'
    # RealVersion
    # Read the ARP DisplayVersion statically from the nested setup.exe of the 7-Zip SFX installer
    # The custom installer (github.com/win32ss/supermium-installer) writes DisplayVersion
    # as a hardcoded string literal, stored right before the "DisplayVersion" field
    # name in its uninstall registration data
    $SetupFile = Expand-SevenZipSfx -Path $InstallerFile -Name 'setup.exe' | Select-Object -First 1
    $SetupBytes = [System.IO.File]::ReadAllBytes($SetupFile)
    $AnchorOffset = (Find-BinaryPattern -Bytes $SetupBytes -Pattern ([System.Text.Encoding]::Unicode.GetBytes('DisplayVersion')) -Maximum 1)[0]
    foreach ($Offset in (Find-BinaryPattern -Bytes $SetupBytes -Pattern ([System.Text.Encoding]::Unicode.GetBytes('1')) -StartOffset ($AnchorOffset - 256) -Length 256)) {
      $EndOffset = $Offset
      while ($EndOffset + 1 -lt $SetupBytes.Length -and ($SetupBytes[$EndOffset] -ne 0 -or $SetupBytes[$EndOffset + 1] -ne 0)) { $EndOffset += 2 }
      $Candidate = [System.Text.Encoding]::Unicode.GetString($SetupBytes, $Offset, $EndOffset - $Offset)
      if ($Candidate -match '^\d+\.\d+\.\d+\.\d+( \S+)?$') { $this.CurrentState.RealVersion = $Candidate }
    }
    if ([string]::IsNullOrWhiteSpace($this.CurrentState.RealVersion)) { throw 'Failed to extract the real version from the installer' }

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
