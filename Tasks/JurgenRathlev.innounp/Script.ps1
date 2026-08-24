function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'innounp.exe' | Out-Host
  $InstallerFile2 = Join-Path $InstallerFileExtracted 'innounp.exe'
  # Version
  $this.CurrentState.Version = $InstallerFile2 | Read-ProductVersionFromExe
  Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

$FolderPath = 'innounp-2/bin'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/jrathlev/InnoUnpacker-Windows-GUI/contents/${FolderPath}"
$VersionedFiles = foreach ($File in $Object1) {
  if ($File.type -ceq 'file' -and $File.name -match '^innounp-(?<Version>\d+(?:\.\d+)*)\.zip$') {
    [pscustomobject]@{
      File    = $File
      Version = [ChunkVersion]$Matches.Version
    }
  }
}
$LatestFile = $VersionedFiles | Sort-Object -Property Version -Bottom 1
if (-not $LatestFile) { throw "No versioned innounp ZIP file was found in '${FolderPath}'." }

$Path = $LatestFile.File.path
$Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/jrathlev/InnoUnpacker-Windows-GUI/commits?path=${Path}&per_page=1"
if (-not $Object2) { throw "No commit was found for the selected innounp archive '${Path}'." }

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://raw.githubusercontent.com/jrathlev/InnoUnpacker-Windows-GUI/$($Object2[0].sha)/${Path}"
}

# Case 0: Force submitting the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: This is a new task
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  return
}

# Case 2: The InstallerUrl is unchanged
if ($this.CurrentState.Installer[0].InstallerUrl -eq $this.LastState.Installer[0].InstallerUrl) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
