# Official versioned installers are published as repository files: x86 at the root, x64 and arm64 in their own folders.
$RootFiles = Invoke-GitHubApi -Uri "https://api.github.com/repos/nyam1003/imagine/contents/"
$X64Files = Invoke-GitHubApi -Uri "https://api.github.com/repos/nyam1003/imagine/contents/x64"
$Arm64Files = Invoke-GitHubApi -Uri "https://api.github.com/repos/nyam1003/imagine/contents/arm64"

$VersionedFiles = foreach ($File in @($RootFiles + $X64Files + $Arm64Files)) {
  if ($File.type -ceq 'file' -and $File.name -match '^Imagine_(?<Version>\d+\.\d+\.\d+)_(?:x64_|arm64_)?Unicode_Full\.exe$') {
    [pscustomobject]@{
      File    = $File
      Version = [ChunkVersion]$Matches.Version
    }
  }
}
$LatestVersion = ($VersionedFiles | Sort-Object -Property Version -Bottom 1).Version
if (-not $LatestVersion) { throw 'No versioned Imagine installer was found in the repository.' }

# Version
$this.CurrentState.Version = [string]$LatestVersion

# Installer (each file pinned to its latest commit so the URLs are immutable)
$ArchFiles = @($VersionedFiles | Where-Object { $_.Version -eq $LatestVersion } | ForEach-Object {
    $Arch = if ($_.File.path -match '^x64/') { 'x64' } elseif ($_.File.path -match '^arm64/') { 'arm64' } else { 'x86' }
    [pscustomobject]@{ Arch = $Arch; File = $_.File }
  })
foreach ($Arch in @('x86', 'x64', 'arm64')) {
  $ArchFile = $ArchFiles.Where({ $_.Arch -eq $Arch }, 'First')[0]
  if (-not $ArchFile) { throw "The $Arch installer for version $LatestVersion was not found." }
  $Commit = Invoke-GitHubApi -Uri "https://api.github.com/repos/nyam1003/imagine/commits?path=$($ArchFile.File.path)&per_page=1"
  if (-not $Commit) { throw "No commit was found for the installer '$($ArchFile.File.path)'." }
  $this.CurrentState.Installer += [ordered]@{
    Architecture  = $Arch
    InstallerType = 'nullsoft'
    InstallerUrl  = "https://raw.githubusercontent.com/nyam1003/imagine/$($Commit[0].sha)/$($ArchFile.File.path)"
  }
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri 'https://www.nyam.pe.kr/dev/imagine/whatsnew/').RawContentStream)

      while (-not $Object2.EndOfStream) {
        $String = $Object2.ReadLine()
        if ($String -match "^v$([regex]::Escape($this.CurrentState.Version))") {
          try {
            # ReleaseTime
            $this.CurrentState.ReleaseTime = [regex]::Match($String, '([a-zA-Z]+\W+\d{1,2}\W+20\d{2})').Groups[1].Value | Get-Date -Format 'yyyy-MM-dd'
          } catch {
            $this.Log("No ReleaseTime for version $($this.CurrentState.Version)", 'Warning')
          }
          break
        }
      }
      if (-not $Object2.EndOfStream) {
        $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
        while (-not $Object2.EndOfStream) {
          $String = $Object2.ReadLine()
          if ($String -notmatch '^v\d+(\.\d+)+,') {
            $ReleaseNotesObjects.Add($String)
          } else {
            break
          }
        }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesObjects | Format-Text
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
    $this.Submit()
  }
}
