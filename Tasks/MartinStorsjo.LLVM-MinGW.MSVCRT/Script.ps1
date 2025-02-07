$RepoOwner = 'mstorsjo'
$RepoName = 'llvm-mingw'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$NameMatches = [regex]::Match($Object1.name, 'llvm-mingw (?<date>\d+) with LLVM (?<version>\d+(?:\.\d+)+)')
$this.CurrentState.Version = "$($NameMatches.Groups['version'].Value)-$($NameMatches.Groups['date'].Value)"

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('msvcrt') -and $_.name.Contains('i686') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('msvcrt') -and $_.name.Contains('x86_64') }, 'First')[0].browser_download_url | ConvertTo-UnescapedUri
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
          Value  = $Object1.body | Convert-MarkdownToHtml -Extensions $MarkdigSoftlineBreakAsHardlineExtension | Get-TextContent | Format-Text
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

    foreach ($Installer in $this.CurrentState.Installer) {
      $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      # InstallerSha256
      $Installer.InstallerSha256 = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash
      # NestedInstallerFiles
      $Installer.NestedInstallerFiles = @(7z.exe l -ba -slt $InstallerFile '*\bin\*.exe' | Where-Object -FilterScript { $_ -match '^Path = ' } | ForEach-Object -Process { [ordered]@{ RelativeFilePath = [regex]::Match($_, '^Path = (.+)').Groups[1].Value } })
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
