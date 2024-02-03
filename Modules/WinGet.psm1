# Apply default function parameters
if ($DumplingsDefaultParameterValues) { $PSDefaultParameterValues = $DumplingsDefaultParameterValues }

# Force stop on error
$ErrorActionPreference = 'Stop'

# Common parameters
$UpstreamOwner = $Global:DumplingsPreference.UpstreamOwner
$UpstreamRepo = $Global:DumplingsPreference.UpstreamRepo
$UpstreamBranch = $Global:DumplingsPreference.UpstreamBranch
$OriginOwner = $Global:DumplingsPreference.OriginOwner
$OriginRepo = $Global:DumplingsPreference.OriginRepo

function New-WinGetManifest {
  <#
  .SYNOPSIS
    Generate and submit WinGet package manifests
  .DESCRIPTION
    Generate WinGet package manifests, upload them to the origin repository and create a pull request in the upstream repository
    Specifically, it does the following:
    1. Check existing pull requests in upstream.
    2. Generate new manifests using the information from current state.
    3. Validate new manifests.
    4. Upload new manifests to origin.
    5. Create pull requests in upstream.
  #>
  param (
    [Parameter(Mandatory)]
    $Task
  )

  #region Parameters
  $PackageIdentifier = $Task.Config.WinGetIdentifier
  $PackageVersion = $Task.CurrentState['RealVersion'] ?? $Task.CurrentState['Version']
  if (Test-Path Env:\GITHUB_WORKSPACE) {
    $ManifestsFolder = Join-Path $Env:GITHUB_WORKSPACE $Script:UpstreamRepo 'manifests' -Resolve
  } else {
    $ManifestsFolder = Join-Path $Global:DumplingsRoot '..' $Script:UpstreamRepo 'manifests' -Resolve
  }
  $OutFolder = (New-Item -Path (Join-Path $Global:LocalCache $PackageIdentifier $PackageVersion) -ItemType Directory -Force).FullName
  #endregion

  #region Check existing pull requests in the upstream repository
  $Task.Logging('Checking existing pull requests', 'Verbose')
  $PullRequests = Invoke-GitHubApi -Uri "https://api.github.com/search/issues?q=repo:${Script:UpstreamOwner}/${Script:UpstreamRepo} is:pr $($PackageIdentifier.Replace('.', '/'))/${PackageVersion} in:path&per_page=1"
  if ($PullRequests.total_count -gt 0) {
    if (-not ($Global:DumplingsPreference.Contains('NoCheck') -and $Global:DumplingsPreference.NoCheck) -and -not ($Task.Config.Contains('IgnorePRCheck') -and $Task.Config.IgnorePRCheck)) {
      $Task.Logging("Existing pull request found: $($PullRequests.items[0].title) - $($PullRequests.items[0].html_url)", 'Error')
      return
    } else {
      $Task.Logging("Existing pull request found: $($PullRequests.items[0].title) - $($PullRequests.items[0].html_url)", 'Warning')
    }
  }
  #endregion

  #region Create manifests using YamlCreate
  $Task.Logging('Creating manifests', 'Verbose')
  try {
    $Parameters = @{
      PackageIdentifier = $PackageIdentifier
      PackageVersion    = $PackageVersion
      PackageInstallers = $Task.CurrentState.Installer
      Locales           = $Task.CurrentState.Locale
      ManifestsFolder   = $ManifestsFolder
      OutFolder         = $OutFolder
    }
    if ($Task.CurrentState.ReleaseTime) {
      if ($Task.CurrentState.ReleaseTime -is [datetime]) {
        $Parameters.PackageReleaseDate = $Task.CurrentState.ReleaseTime.ToUniversalTime().ToString('yyyy-MM-dd')
      } else {
        $Parameters.PackageReleaseDate = $Task.CurrentState.ReleaseTime | Get-Date -Format 'yyyy-MM-dd'
      }
    }
    & (Join-Path $PSScriptRoot '..' 'Utilities' 'YamlCreate.ps1') @Parameters
  } catch {
    $Task.Logging("Failed to create manifests: ${_}", 'Error')
    $_ | Out-Host
    return
  }
  $Task.Logging('Manifests created', 'Verbose')
  #endregion

  #region Validate manifests using WinGet client
  $Task.Logging('Validating manifests', 'Verbose')
  if (-not (Get-Command 'winget' -ErrorAction SilentlyContinue)) {
    $Task.Logging('Could not find WinGet client', 'Error')
    return
  }
  $WinGetOutput = ''
  winget validate $OutFolder | Out-String -OutVariable 'WinGetOutput'
  if ($LASTEXITCODE -notin @(0, -1978335192)) {
    $Task.Logging("Validation failed: `n${WinGetOutput}", 'Error')
    return
  }
  $Task.Logging('Validation passed', 'Verbose')
  #endregion

  #region Upload new manifests, remove old manifests if needed, and commit in the origin repository
  $Task.Logging('Uploading manifests and committing', 'Verbose')
  try {
    $NewBranchName = "${PackageIdentifier}-${PackageVersion}-$((New-Guid).Guid.Split('-')[-1])" -replace '[\~,\^,\:,\\,\?,\@\{,\*,\[,\s]{1,}|[.lock|/|\.]*$|^\.{1,}|\.\.', ''
    $NewCommitName = "New version: ${PackageIdentifier} version ${PackageVersion}"

    $UpstreamSha = $Global:LocalStorage['UpstreamSha'] ??= (Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:UpstreamOwner}/${Script:UpstreamRepo}/git/ref/heads/${Script:UpstreamBranch}").object.sha
    $NewBranchSha = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:OriginOwner}/${Script:OriginRepo}/git/refs" -Method Post -Body @{
        ref = "refs/heads/${NewBranchName}"
        sha = $UpstreamSha
      }
    ).object.sha

    # Upload new manifests and obtain their SHA
    $NewFileNameSha = @()
    Get-ChildItem -Path $OutFolder -Include '*.yaml' -Recurse -File | ForEach-Object -Process {
      $NewFileNameSha += @{
        Path = "manifests/$($PackageIdentifier.ToLower().Chars(0))/$($PackageIdentifier.Replace('.', '/'))/${PackageVersion}/$($_.Name)"
        Sha  = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:OriginOwner}/${Script:OriginRepo}/git/blobs" -Method Post -Body @{
            content  = Get-Content -Path $_ -Raw -Encoding utf8NoBOM
            encoding = 'utf-8'
          }
        ).sha
      }
    }

    # Find the latest version of manifests to remove in the upstream repo, if needed
    if ($Task.Config.Contains('RemoveLastVersion') -and $Task.Config.RemoveLastVersion) {
      $LastManifestVersion = Get-ChildItem -Path "${ManifestsFolder}\$($PackageIdentifier.ToLower().Chars(0))\$($PackageIdentifier.Replace('.', '\'))\*\${PackageIdentifier}.yaml" -File |
        Split-Path -Parent | Split-Path -Leaf |
        Sort-Object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) } -Culture en-US | Select-Object -Last 1
      if ($LastManifestVersion -ne $PackageVersion) {
        $Task.Logging("Manifests for last version ${LastManifestVersion} will be removed", 'Info')
        Get-ChildItem -Path "${ManifestsFolder}\$($PackageIdentifier.ToLower().Chars(0))\$($PackageIdentifier.Replace('.', '\'))\${LastManifestVersion}\*.yaml" -File | ForEach-Object -Process {
          $NewFileNameSha += @{
            Path = "manifests/$($PackageIdentifier.ToLower().Chars(0))/$($PackageIdentifier.Replace('.', '/'))/${LastManifestVersion}/$($_.Name)"
            Sha  = $null
          }
        }
      } else {
        $Task.Logging("Manifests for last version ${LastManifestVersion} will be overrided", 'Info')
      }
    }

    # Build a new tree with changes of creating new manifests and removing old manifests based on the branch, obtaining the SHA of the new tree
    $TreeSha = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:OriginOwner}/${Script:OriginRepo}/git/trees" -Method Post -Body @{
        tree      = @($NewFileNameSha | ForEach-Object -Process {
            @{
              path = $_.Path
              mode = '100644'
              type = 'blob'
              sha  = $_.Sha
            }
          })
        base_tree = $NewBranchSha
      }).sha

    # Commit with the new tree, obtaining the SHA of the commit
    $CommitSha = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:OriginOwner}/${Script:OriginRepo}/git/commits" -Method Post -Body @{
        tree    = $TreeSha
        message = $NewCommitName
        parents = @($NewBranchSha)
      }
    ).sha

    # Move the HEAD of the branch to the commit
    Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:OriginOwner}/${Script:OriginRepo}/git/refs/heads/${NewBranchName}" -Method Post -Body @{
      sha = $CommitSha
    } | Out-Null
  } catch {
    $Task.Logging("Failed to upload manifests or commit: ${_}", 'Error')
    $_ | Out-Host
    return
  }
  $Task.Logging('Manifests uploaded and committed', 'Verbose')
  #endregion

  #region Create pull request in the upstream repository
  $Task.Logging('Creating pull request', 'Verbose')
  try {
    if (Test-Path Env:\CI) {
      $NewPRBody = "This pull request is automatically generated by [🥟 Dumplings](https://github.com/SpecterShell/Dumplings) in [#${Env:GITHUB_RUN_NUMBER}](https://github.com/${Script:OriginOwner}/Dumplings/actions/runs/${Env:GITHUB_RUN_ID})"
    } else {
      $NewPRBody = 'This pull request is automatically generated by [🥟 Dumplings](https://github.com/SpecterShell/Dumplings)'
    }
    $NewPRResponse = Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:UpstreamOwner}/${Script:UpstreamRepo}/pulls" -Method Post -Body @{
      title = $NewCommitName
      body  = $NewPRBody
      head  = "${Script:OriginOwner}:${NewBranchName}"
      base  = 'master'
    }
  } catch {
    $Task.Logging("Failed to create pull request: ${_}", 'Error')
    $_ | Out-Host
    return
  }
  $Task.Logging("Pull request created: $($NewPRResponse.html_url)", 'Info')
  #endregion

}
