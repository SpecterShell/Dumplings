function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'innounp.exe' | Out-Host
  $InstallerFile2 = Join-Path $InstallerFileExtracted 'innounp.exe'
  # Version
  $this.CurrentState.Version = $InstallerFile2 | Read-ProductVersionFromExe
  Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

$RepoOwner = 'jrathlev'
$RepoName = 'InnoUnpacker-Windows-GUI'
$Path = 'innounp-2/bin/innounp-2.zip'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/commits?path=${Path}"

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = "https://raw.githubusercontent.com/${RepoOwner}/${RepoName}/$($Object1[0].sha)/${Path}"
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
