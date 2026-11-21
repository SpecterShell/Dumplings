# x86
$PrefixX86 = 'https://artifacts.videolan.org/vlc/nightly-win32-llvm/'
$Object1 = Invoke-WebRequest -Uri $PrefixX86
$VersionX86Long = $Object1.Links.Where({ try { $_.href -match '^\d{8}-\d{4}/$' } catch {} }).href | Sort-Object -Property { [ChunkVersion]($_) } -Bottom 1
$VersionX86 = [regex]::Match($VersionX86Long, '^(\d{8})-\d{4}/$').Groups[1].Value
$Object2 = Invoke-WebRequest -Uri ($PrefixX86 += $VersionX86Long)

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x86'
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri $PrefixX86 $Object2.Links.Where({ $_.href.EndsWith('.msi') }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x86'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = Join-Uri $PrefixX86 $Object2.Links.Where({ $_.href.EndsWith('.zip') -and $_.href -notmatch 'debug' }, 'First')[0].href
}

# x64
$PrefixX64 = 'https://artifacts.videolan.org/vlc/nightly-win64-llvm/'
$Object3 = Invoke-WebRequest -Uri $PrefixX64
$VersionX64Long = $Object3.Links.Where({ try { $_.href -match '^\d{8}-\d{4}/$' } catch {} }).href | Sort-Object -Property { [ChunkVersion]($_) } -Bottom 1
$VersionX64 = [regex]::Match($VersionX64Long, '^(\d{8})-\d{4}/$').Groups[1].Value
$Object4 = Invoke-WebRequest -Uri ($PrefixX64 += $VersionX64Long)

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'x64'
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri $PrefixX64 $Object4.Links.Where({ $_.href.EndsWith('.msi') }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'x64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = Join-Uri $PrefixX64 $Object4.Links.Where({ $_.href.EndsWith('.zip') -and $_.href -notmatch 'debug' }, 'First')[0].href
}

# ARM64
$PrefixARM64 = 'https://artifacts.videolan.org/vlc/nightly-win64-arm-llvm/'
$Object5 = Invoke-WebRequest -Uri $PrefixARM64
$VersionARM64Long = $Object5.Links.Where({ try { $_.href -match '^\d{8}-\d{4}/$' } catch {} }).href | Sort-Object -Property { [ChunkVersion]($_) } -Bottom 1
$VersionARM64 = [regex]::Match($VersionARM64Long, '^(\d{8})-\d{4}/$').Groups[1].Value
$Object6 = Invoke-WebRequest -Uri ($PrefixARM64 += $VersionARM64Long)

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture  = 'arm64'
  InstallerType = 'wix'
  InstallerUrl  = Join-Uri $PrefixARM64 $Object6.Links.Where({ $_.href.EndsWith('.msi') }, 'First')[0].href
}
$this.CurrentState.Installer += [ordered]@{
  Architecture        = 'arm64'
  InstallerType       = 'zip'
  NestedInstallerType = 'portable'
  InstallerUrl        = Join-Uri $PrefixARM64 $Object6.Links.Where({ $_.href.EndsWith('.zip') -and $_.href -notmatch 'debug' }, 'First')[0].href
}

if (@(@($VersionX86, $VersionX64, $VersionARM64) | Sort-Object -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x86: $VersionX86, x64: $VersionX64, arm64: $VersionARM64", 'Error')
  return
}

if ($this.CurrentState.Installer[0].InstallerUrl -notmatch '(\d+(?:\.\d+)+)') { throw 'Failed to parse main version from InstallerUrl' }

# Version
$this.CurrentState.Version = "$($Matches[1])-nightly.$VersionX64"

# RealVersion
$this.CurrentState.RealVersion = $Matches[1]

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    foreach ($Installer in $this.CurrentState.Installer) {
      if ($Installer.InstallerType -eq 'zip' -and $Installer.NestedInstallerType -eq 'portable') {
        $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
        $ZipFile = [System.IO.Compression.ZipFile]::OpenRead($InstallerFile)
        $Installer['NestedInstallerFiles'] = @(
          [ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.Name -eq 'vlc.exe' }, 'First')[0].FullName.Replace('/', '\') }
          [ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.Name -eq 'vlc-cache-gen.exe' }, 'First')[0].FullName.Replace('/', '\') }
          [ordered]@{ RelativeFilePath = $ZipFile.Entries.Where({ $_.Name -eq 'vlc-preparser.exe' }, 'First')[0].FullName.Replace('/', '\') }
        )
        $ZipFile.Dispose()
      }
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
