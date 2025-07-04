$RepoOwner = 'pseymour'
$RepoName = 'MakeMeAdmin'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/contents/Installers/en-us"
# x86
$InstallerX86Path = $Object1.Where({ $_.name.EndsWith('.msi') -and $_.Name.Contains('x86') }, 'First')[0].path
$VersionX86 = [regex]::Match($InstallerX86Path, '(\d+(\.\d+)+)').Groups[1].Value
# x64
$InstallerX64Path = $Object1.Where({ $_.name.EndsWith('.msi') -and $_.Name.Contains('x64') }, 'First')[0].path
$VersionX64 = [regex]::Match($InstallerX64Path, '(\d+(\.\d+)+)').Groups[1].Value

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

# Installer
$Object2 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/commits?path=${InstallerX86Path}"
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = "https://raw.githubusercontent.com/${RepoOwner}/${RepoName}/$($Object2[0].sha)/${InstallerX86Path}"
}
$Object3 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/commits?path=${InstallerX64Path}"
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = "https://raw.githubusercontent.com/${RepoOwner}/${RepoName}/$($Object3[0].sha)/${InstallerX64Path}"
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object2[0].commit.author.date.ToUniversalTime()
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
