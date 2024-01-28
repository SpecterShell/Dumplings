$RepoOwner = 'qjfoidnh'
$RepoName = 'BaiduPCS-Go'

$Object1 = Invoke-GitHubApi -Uri "https://api.github.com/repos/${RepoOwner}/${RepoName}/releases/latest"

# Version
$this.CurrentState.Version = $Object1.tag_name -creplace '^v'

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x86'
  InstallerUrl         = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('windows') -and $_.name.Contains('x86') })[0].browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "BaiduPCS-Go-v$($this.CurrentState.Version)-windows-x86\BaiduPCS-Go.exe"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'x64'
  InstallerUrl         = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('windows') -and $_.name.Contains('x64') })[0].browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "BaiduPCS-Go-v$($this.CurrentState.Version)-windows-x64\BaiduPCS-Go.exe"
    }
  )
}
$this.CurrentState.Installer += [ordered]@{
  Architecture         = 'arm'
  InstallerUrl         = $Object1.assets.Where({ $_.name.EndsWith('.zip') -and $_.name.Contains('windows') -and $_.name -match '[^a-zA-Z0-9]arm[^a-zA-Z0-9]' })[0].browser_download_url | ConvertTo-UnescapedUri
  NestedInstallerFiles = @(
    [ordered]@{
      RelativeFilePath = "BaiduPCS-Go-v$($this.CurrentState.Version)-windows-arm\BaiduPCS-Go.exe"
    }
  )
}

# ReleaseTime
$this.CurrentState.ReleaseTime = $Object1.published_at.ToUniversalTime()

if (-not [string]::IsNullOrWhiteSpace($Object1.body)) {
  # ReleaseNotes (zh-CN)
  $this.CurrentState.Locale += [ordered]@{
    Locale = 'zh-CN'
    Key    = 'ReleaseNotes'
    Value  = ($Object1.body | ConvertFrom-Markdown).Html | ConvertFrom-Html | Get-TextContent | Format-Text
  }
} else {
  $this.Logging("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
}

# ReleaseNotesUrl
$this.CurrentState.Locale += [ordered]@{
  Key   = 'ReleaseNotesUrl'
  Value = $Object1.html_url
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
