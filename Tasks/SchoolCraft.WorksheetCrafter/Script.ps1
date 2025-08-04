function Read-Installer {
  $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  # Version
  $this.CurrentState.Version = $InstallerFile | Read-ProductVersionFromExe
  # InstallerSha256
  $this.CurrentState.Installer[0]['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
  Remove-Item -Path $InstallerFile -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

$Object1 = Invoke-WebRequest -Uri 'https://worksheetcrafter.com/de/downloads/vollversion'
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Links.Where({ $_.outerHTML.Contains('Download für Windows') }, 'First')[0].href
}

$Object2 = Invoke-WebRequest -Uri $this.CurrentState.Installer[0].InstallerUrl -Method Head
# Content Length
$this.CurrentState.ContentLength = $Object2.Headers.'Content-Length'[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  $this.Message()
  $this.Submit()
  return
}

# Case 1: The task is new
if ($this.Status.Contains('New')) {
  $this.Log('New task', 'Info')

  Read-Installer

  $this.Print()
  $this.Write()
  return
}

# Case 2: The Content Length is unchanged
if ($this.CurrentState.ContentLength -eq $this.LastState.ContentLength) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest", 'Info')
  return
}

Read-Installer

switch -Regex ($this.Check()) {
  # Case 4: The Content Length and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 3: The Content Length has changed, but the version is not
  default {
    $this.Log('The Content Length and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
}
