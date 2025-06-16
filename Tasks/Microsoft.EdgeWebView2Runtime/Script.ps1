function Read-Installer {
  $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
  $InstallerFileExtracted = New-TempFolder
  7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile '*~' | Out-Host
  $InstallerFile2 = Join-Path $InstallerFileExtracted '*~' | Get-Item -Force | Select-Object -First 1
  $InstallerFile2Extracted = New-TempFolder
  $InstallerFile3Name = [regex]::Matches((7z.exe l -ba -slt '-t#' $InstallerFile2), 'Path = (\d+\.tar)')[-1].Groups[1].Value
  7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFile2Extracted}" $InstallerFile2 $InstallerFile3Name | Out-Host
  $InstallerFile3 = Join-Path $InstallerFile2Extracted $InstallerFile3Name
  # Version
  $this.CurrentState.Version = [regex]::Match((7z.exe e -y '-t#' -so $InstallerFile3 '1'), '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value
  Remove-Item -Path $InstallerFile2Extracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
  Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
}

# x86
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2099617'
}
$Object1 = Invoke-WebRequest -Uri $InstallerX86.InstallerUrl -Method Head
$ETag = $Object1.Headers.ETag[0]

# x64
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2124701'
}
$Object2 = Invoke-WebRequest -Uri $InstallerX64.InstallerUrl -Method Head
$ETagX64 = $Object2.Headers.ETag[0]

# arm64
$this.CurrentState.Installer += $InstallerARM64 = [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2099616'
}
$Object3 = Invoke-WebRequest -Uri $InstallerARM64.InstallerUrl -Method Head
$ETagARM64 = $Object3.Headers.ETag[0]

# Case 0: Force submit the manifest
if ($Global:DumplingsPreference.Contains('Force')) {
  $this.Log('Skip checking states', 'Info')

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagX64 = @($ETagX64)
  $this.CurrentState.ETagARM64 = @($ETagARM64)

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

  # ETag
  $this.CurrentState.ETag = @($ETag)
  $this.CurrentState.ETagX64 = @($ETagX64)
  $this.CurrentState.ETagARM64 = @($ETagARM64)

  Read-Installer

  $this.Print()
  $this.Write()
  return
}

# Case 2: The ETag is unchanged
if ($ETag -in $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (MSI)", 'Info')
  return
}
if ($ETagX64 -in $this.LastState.ETagX64) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (EXE)", 'Info')
  return
}
if ($ETagARM64 -in $this.LastState.ETagARM64) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest (ARM64)", 'Info')
  return
}

Read-Installer

# Case 3: The current state has an invalid version
if ([string]::IsNullOrWhiteSpace($this.CurrentState.Version)) {
  throw 'The current state has an invalid version'
}

# Case 4: The ETag has changed, but the SHA256 is not
if ($this.CurrentState.Installer[0].InstallerSha256 -eq $this.LastState.Installer[0].InstallerSha256) {
  $this.Log('The ETag has changed, but the SHA256 is not', 'Info')

  # ETag
  $this.CurrentState.ETag = $this.LastState.ETag + $ETag
  $this.CurrentState.ETagX64 = $this.LastState.ETagX64 + $ETagX64
  $this.CurrentState.ETagARM64 = $this.LastState.ETagARM64 + $ETagARM64

  $this.Write()
  return
}

# ETag
$this.CurrentState.ETag = @($ETag)
$this.CurrentState.ETagX64 = @($ETagX64)
$this.CurrentState.ETagARM64 = @($ETagARM64)

switch -Regex ($this.Check()) {
  # Case 6: The ETag, the SHA256 and the version have changed
  'Updated|Rollbacked' {
    $this.Print()
    $this.Write()
    $this.Message()
    $this.Submit()
  }
  # Case 5: The ETag and the SHA256 have changed, but the version is not
  Default {
    $this.Log('The ETag and the SHA256 have changed, but the version is not', 'Info')
    $this.Config.IgnorePRCheck = $true
    $this.Print()
    $this.Write()
    $this.Message()
    if (Compare-Object -ReferenceObject $this.LastState.Installer.InstallerUrl -DifferenceObject $this.CurrentState.Installer.InstallerUrl -IncludeEqual -ExcludeDifferent) {
      throw 'Not all installers have been updated'
    }
    $this.Submit()
  }
}
