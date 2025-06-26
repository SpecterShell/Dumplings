$Prefix = 'https://www.bennewitz.com/bluefish/stable/binaries/windows_x64/'

$Object1 = Invoke-WebRequest -Uri "${Prefix}?C=N;O=D;V=1;P=*.exe;F=0"

$InstallerName = $Object1.Links | Select-Object -ExpandProperty 'href' -ErrorAction SilentlyContinue | ConvertTo-UnescapedUri | Where-Object -FilterScript { $_ -match '^Bluefish (\d+(?:\.\d+)+) Setup\.exe$' } | Sort-Object -Property { $_ -creplace '\d+', { $_.Value.PadLeft(20) } } -Bottom 1

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl         = Join-Uri $Prefix $InstallerName
  InstallationMetadata = [ordered]@{
    DefaultInstallLocation = '%ProgramFiles(x86)%\Bluefish'
    Files                  = @(
      [ordered]@{
        RelativeFilePath = 'bluefish.exe'
      }
    )
  }
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'bluefish.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted 'bluefish.exe'
    # InstallationMetadata > Files > FileSha256
    $this.CurrentState.Installer.ForEach({ $_.InstallationMetadata.Files[0]['FileSha256'] = (Get-FileHash -Path $InstallerFile2 -Algorithm SHA256).Hash })
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

    try {
      $Object2 = Invoke-WebRequest -Uri 'https://bluefish.openoffice.nl/' | ConvertFrom-Html

      $ReleaseNotesTitleNode = $Object2.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")
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
        $this.Log("No ReleaseTime and ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
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
