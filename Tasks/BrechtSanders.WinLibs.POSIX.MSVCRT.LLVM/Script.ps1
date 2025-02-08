$RepoOwner = 'brechtsanders'
$RepoName = 'winlibs_mingw'

$Object1 = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases").Where({ -not $_.prerelease -and $_.tag_name.Contains('posix') -and $_.tag_name.Contains('msvcrt') }, 'First')[0]

$VersionMatches = [regex]::Match($Object1.tag_name, '(?<gcc>\d+(?:\.\d+)+)posix(?:-(?<llvm>\d+(?:\.\d+)+))?-(?<mingw>\d+(?:\.\d+)+)-msvcrt-r(?<release>\d+)')
if (-not $VersionMatches.Groups['llvm'].Success) {
  throw "The build $($Object1.tag_name) does not contain LLVM"
}

# Version
$this.CurrentState.Version = [ComplexVersion]"$($VersionMatches.Groups['gcc'].Value)-$($VersionMatches.Groups['llvm'].Value)-$($VersionMatches.Groups['mingw'].Value)-r$($VersionMatches.Groups['release'].Value)"

# Installer
$this.CurrentState.Installer += $InstallerX86 = [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('llvm') -and $_.name.Contains('i686') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += $InstallerX64 = [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('llvm') -and $_.name.Contains('x86_64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

      if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Object1.body | Convert-MarkdownToHtml -Extensions 'advanced', 'emojis', 'hardlinebreak' | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }

      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $Object1.html_url
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $InstallerFileX86 = Get-TempFile -Uri $InstallerX86.InstallerUrl
    # InstallerSha256
    $InstallerX86.InstallerSha256 = (Get-FileHash -Path $InstallerFileX86 -Algorithm SHA256).Hash
    # NestedInstallerFiles
    $InstallerX86.NestedInstallerFiles = @(7z.exe l -ba -slt $InstallerFileX86 'mingw32\bin\*.exe' | Where-Object -FilterScript { $_ -match '^Path = ' } | ForEach-Object -Process { [ordered]@{ RelativeFilePath = [regex]::Match($_, '^Path = (.+)').Groups[1].Value } })

    $InstallerFileX64 = Get-TempFile -Uri $InstallerX64.InstallerUrl
    # InstallerSha256
    $InstallerX64.InstallerSha256 = (Get-FileHash -Path $InstallerFileX64 -Algorithm SHA256).Hash
    # NestedInstallerFiles
    $InstallerX64.NestedInstallerFiles = @(7z.exe l -ba -slt $InstallerFileX64 'mingw64\bin\*.exe' | Where-Object -FilterScript { $_ -match '^Path = ' } | ForEach-Object -Process { [ordered]@{ RelativeFilePath = [regex]::Match($_, '^Path = (.+)').Groups[1].Value } })

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
