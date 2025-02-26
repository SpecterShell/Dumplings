$Object1 = Invoke-WebRequest -Uri 'https://www.xbench.net/index.php/download'

# Installer
$Link = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('x32') } catch {} }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = $Link.href
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "$($Link.href | Split-Path -LeafBase).exe"
    }
  )
}
$Link = $Object1.Links.Where({ try { $_.href.EndsWith('.zip') -and $_.href.Contains('x64') } catch {} }, 'First')[0]
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $Link.href
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "$($Link.href | Split-Path -LeafBase).exe"
    }
  )
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+){2})\.zip').Groups[1].Value
$VersionParts = $this.CurrentState.Version.Split('.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted $this.CurrentState.Installer[0].NestedInstallerFiles[0].RelativeFilePath
    $InstallerFile2Extracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFile2Extracted}" $InstallerFile2 'xbench.exe' | Out-Host
    $InstallerFile3 = Join-Path $InstallerFile2Extracted 'xbench.exe'

    # InstallerSha256
    $this.CurrentState.Installer[0].InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile3 | Read-FileVersionFromExe

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://www.xbench.net/index.php/support/change-log' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(text(), '$($VersionParts[0]).$($VersionParts[1]) Build $($VersionParts[2])')]")
      if ($ReleaseNotesTitleNode) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime = [regex]::Match($ReleaseNotesTitleNode.InnerText, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'

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
