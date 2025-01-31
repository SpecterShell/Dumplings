function Get-WinGetPackageVersion {
  <#
  .SYNOPSIS
    Get the versions of a package
  .DESCRIPTION
    Get the versions of a package from the winget-pkgs repository
  .PARAMETER PackageIdentifier
    The identifier of the package
  .PARAMETER Root
    The root path of the winget-pkgs repository
  #>
  [CmdletBinding()]
  [OutputType([string[]])]
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The identifier of the package')]
    [string]$PackageIdentifier,

    [Parameter(Position = 1, Mandatory, HelpMessage = 'The root path of the winget-pkgs repository')]
    [string]$Root
  )

  process {
    @(
      Get-ChildItem -Path "${Root}\$($PackageIdentifier.ToLower().Chars(0))\$($PackageIdentifier.Replace('.', '\'))\*\${PackageIdentifier}.yaml" -File |
        Split-Path -Parent | Split-Path -Leaf |
        Sort-Object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) } -Culture en-US -Stable
    )
  }
}

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
  .PARAMETER Task
    The task object to be handled
  #>
  param (
    [Parameter(Position = 0, ValueFromPipeline, Mandatory, HelpMessage = 'The task object to be handled')]
    $Task
  )

  #region Parameters
  # Static parameters for repos
  $UpstreamOwner = $Global:DumplingsPreference.UpstreamOwner
  $UpstreamRepo = $Global:DumplingsPreference.UpstreamRepo
  # $UpstreamBranch = $Global:DumplingsPreference.UpstreamBranch
  $OriginOwner = $Global:DumplingsPreference.OriginOwner
  $OriginRepo = $Global:DumplingsPreference.OriginRepo
  $OriginBranch = $Global:DumplingsPreference.OriginBranch

  # Static parameters for YamlCreate
  if (Test-Path Env:\GITHUB_WORKSPACE) {
    $ManifestsFolder = Join-Path $Env:GITHUB_WORKSPACE $UpstreamRepo 'manifests' -Resolve
  } elseif ($Global:DumplingsPreference['WinGetManifestsFolder']) {
    $ManifestsFolder = Resolve-Path -Path $Global:DumplingsPreference.WinGetManifestsFolder
  } elseif (Test-Path Variable:\DumplingsRoot) {
    $ManifestsFolder = Join-Path $Global:DumplingsRoot '..' $UpstreamRepo 'manifests' -Resolve
  } else {
    $ManifestsFolder = Join-Path $PSScriptRoot '..' '..' $UpstreamRepo 'manifests' -Resolve
  }

  # Parameters for the task
  $PackageIdentifier = $Task.Config.WinGetIdentifier
  $PackageVersion = $Task.CurrentState.Contains('RealVersion') ? $Task.CurrentState.RealVersion : $Task.CurrentState.Version
  if ([string]::IsNullOrWhiteSpace($PackageVersion)) { throw 'The current state has an invalid Version/RealVersion' }

  $LastManifestVersion = Get-WinGetPackageVersion -PackageIdentifier $PackageIdentifier -Root $ManifestsFolder | Select-Object -Last 1
  if ([string]::IsNullOrWhiteSpace($LastManifestVersion)) { throw 'Could not find the manifest of previous version of the package' }

  $BranchName = "${PackageIdentifier}-${PackageVersion}-$(Get-Random)" -replace '[\~,\^,\:,\\,\?,\@\{,\*,\[,\s]{1,}|[.lock|/|\.]*$|^\.{1,}|\.\.', ''
  if ($Global:DumplingsPreference['CommitType']) {
    $CommitType = $Global:DumplingsPreference.CommitType
  } else {
    $CommitType = switch (Compare-Version -ReferenceVersion $LastManifestVersion -DifferenceVersion $PackageVersion) {
      1 { 'New version'; continue }
      0 { 'Update'; continue }
      -1 { 'Add version'; continue }
    }
  }
  $CommitName = "${CommitType}: ${PackageIdentifier} version ${PackageVersion}"
  if ($Task.CurrentState.Contains('RealVersion')) { $CommitName += " ($($Task.CurrentState.Version))" }

  $OutFolder = (New-Item -Path (Join-Path $Global:DumplingsOutput 'WinGet' $PackageIdentifier $PackageVersion) -ItemType Directory -Force).FullName
  #endregion

  #region Check existing pull requests in the upstream repository
  $Task.Log('Checking existing pull requests', 'Verbose')

  $OldPRObject = Invoke-GitHubApi -Uri "https://api.github.com/search/issues?q=repo%3A${UpstreamOwner}%2F${UpstreamRepo}%20is%3Apr%20$($PackageIdentifier.Replace('.', '%2F'))%2F${PackageVersion}%20in%3Apath"
  if ($OldPRObject.total_count -gt 0) {
    $Task.Log("Found existing pull requests:`n$($OldPRObject.items | Select-Object -First 3 | ForEach-Object -Process { "$($_.title) - $($_.html_url)" } | Join-String -Separator "`n")", 'Warning')
    if ($Global:DumplingsPreference['Force']) {
      $Task.Log('Forced to ignore existing pull requests', 'Info')
    } elseif ($Task.Config['IgnorePRCheck']) {
      $Task.Log('This task is configured to ignore existing pull requests', 'Info')
    } elseif ($Task.Config['StrictPRCheck']) {
      throw 'Found existing pull requests'
    } elseif ($Task.LastState.Contains('Version') -and $Task.LastState.Contains('RealVersion') -and ($Task.LastState.Version -ne $Task.CurrentState.Version) -and ($Task.LastState.RealVersion -eq $Task.CurrentState.RealVersion)) {
      $Task.Log("The existing pull requests are ignored as the version is updated while the real version isn't", 'Info')
    } elseif ($OldPRObject.items | Where-Object -FilterScript { $_.title -match "(\s|^)$([regex]::Escape($PackageIdentifier))(\s|$)" -and $_.title -match "(\s|^)$([regex]::Escape($PackageVersion))(\s|$)" }) {
      # In some cases, a shorter package identifier may be matched to a longer one, e.g., "Google.Chrome" matches "Google.Chrome.Beta". Check word boundary to avoid this issue
      throw 'Found existing pull requests'
    }
  }
  #endregion

  #region Create manifests using YamlCreate
  $Task.Log('Creating manifests', 'Info')

  try {
    $Parameters = @{
      PackageIdentifier = $PackageIdentifier
      PackageVersion    = $PackageVersion
      InstallerEntries  = $Task.CurrentState.Installer
      LocaleEntries     = $Task.CurrentState.Locale
      ManifestsFolder   = $ManifestsFolder
      OutFolder         = $OutFolder
      Logger            = $Task.Log
    }
    if ($Task.CurrentState['ReleaseTime']) {
      if ($Task.CurrentState.ReleaseTime -is [datetime] -or $Task.CurrentState.ReleaseTime -is [System.DateTimeOffset]) {
        $ReleaseDate = $Task.CurrentState.ReleaseTime.ToUniversalTime().ToString('yyyy-MM-dd')
      } else {
        $ReleaseDate = $Task.CurrentState.ReleaseTime | Get-Date -Format 'yyyy-MM-dd'
      }
      $Task.CurrentState.Installer | ForEach-Object -Process { if (-not $_.Contains('ReleaseDate')) { $_['ReleaseDate'] = $ReleaseDate } }
    }
    & (Join-Path $PSScriptRoot '..' 'Utilities' 'YamlCreate.ps1') @Parameters
  } catch {
    $Task.Log('Failed to create manifests', 'Error')
    throw $_
  }

  $Task.Log('Manifests created', 'Verbose')
  #endregion

  #region Validate manifests using WinGet client
  $Task.Log('Validating manifests', 'Verbose')

  if (-not $Global:DumplingsPreference['NoValidation']) {
    $WinGetOutput = ''
    $WinGetMaximumRetryCount = 3
    for ($i = 0; $i -lt $WinGetMaximumRetryCount; $i++) {
      try {
        winget validate $OutFolder | Out-String -Stream -OutVariable 'WinGetOutput'
        break
      } catch {
        if ($_.FullyQualifiedErrorId -eq 'CommandNotFoundException') {
          $Task.Log('Could not find the WinGet client for validating manifests. Is it installed and added to PATH?', 'Error')
          throw $_
        } elseif ($_.FullyQualifiedErrorId -eq 'ProgramExitedWithNonZeroCode') {
          # WinGet may throw warnings for, for example, not specifying the installer switches for EXE installers
          # Ignore these warnings by checking the exit code as it actually doesn't matter
          if ($_.Exception.ExitCode -eq -1978335192) {
            break
          } else {
            if ($i -eq $WinGetMaximumRetryCount - 1) {
              $Task.Log("Failed to pass manifests validation: $($WinGetOutput -join "`n")", 'Error')
              throw $_
            } else {
              $Task.Log("WinGet exits with exitcode $($_.Exception.ExitCode)", 'Warning')
            }
          }
        } else {
          $Task.Log('Failed to run manifests validation', 'Error')
          throw $_
        }
      }
    }
  } else {
    $Task.Log('Manifests validation is skipped', 'Info')
  }

  $Task.Log('Manifests validation passed', 'Verbose')
  #endregion

  # Do not upload manifests in dry mode
  if ($Global:DumplingsPreference['Dry']) {
    $Task.Log('Running in dry mode. Exiting...', 'Info')
    return
  }

  #region Upload new manifests, remove old manifests if needed, and commit in the origin repository
  $Task.Log('Uploading manifests and making commits', 'Info')

  # Create a new branch
  # The new branch is created from the default branch of the origin repo rather than the one of the upstream repo
  # This is to mitigate the occasional and weird issue of "ref not found" when creating a new branch from the default branch of the upstream repo
  # The origin repo should be synced as early as possible to avoid conflicts with other commits
  $Task.Log('Creating a new branch', 'Verbose')
  $Global:DumplingsSessionStorage['BaseRefSha'] ??= (Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/ref/heads/${OriginBranch}").object.sha
  $NewRefObject = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/refs" -Method Post -Body @{
    ref = "refs/heads/${BranchName}"
    sha = $Global:DumplingsSessionStorage.BaseRefSha
  }

  # Upload new manifests
  $Task.Log('Uploading the manifests', 'Verbose')
  $FileList = @()
  Get-ChildItem -Path $OutFolder -Include '*.yaml' -Recurse -File | ForEach-Object -Process {
    $NewFileObject = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/blobs" -Method Post -Body @{
      content  = Get-Content -Path $_ -Raw -Encoding utf8NoBOM
      encoding = 'utf-8'
    }
    $FileList += @{
      Path = "manifests/$($PackageIdentifier.ToLower().Chars(0))/$($PackageIdentifier.Replace('.', '/'))/${PackageVersion}/$($_.Name)"
      Sha  = $NewFileObject.sha
    }
  }
  if ($FileList.Count -eq 0) {
    throw 'Could not find any manifests to upload'
  }

  # Remove old manifests, if
  # 1. The task is configured to remove the last version, or
  # 2. No installer URL is changed compared with the last state while the version is updated
  $Task.Log('Detecting the manifests to be removed', 'Verbose')
  $RemoveLastVersionReason = $null
  if ($Task.Config['RemoveLastVersion']) {
    $RemoveLastVersionReason = 'This task is configured to remove the last version'
  }
  if ($Task.LastState.Contains('Version') -and ($Task.LastState.Version -ne $Task.CurrentState.Version) -and -not (Compare-Object -ReferenceObject $Task.LastState -DifferenceObject $Task.CurrentState -Property { $_.Installer.InstallerUrl })) {
    $RemoveLastVersionReason = 'No installer URL is changed compared with the last state while the version is updated'
  }
  if ($RemoveLastVersionReason) {
    if ($LastManifestVersion -ne $PackageVersion) {
      $Task.Log("The manifests for the last version ${LastManifestVersion} will be removed. Reason: ${RemoveLastVersionReason}", 'Info')
      Get-ChildItem -Path "${ManifestsFolder}\$($PackageIdentifier.ToLower().Chars(0))\$($PackageIdentifier.Replace('.', '\'))\${LastManifestVersion}\*.yaml" -File | ForEach-Object -Process {
        $FileList += @{
          Path = "manifests/$($PackageIdentifier.ToLower().Chars(0))/$($PackageIdentifier.Replace('.', '/'))/${LastManifestVersion}/$($_.Name)"
          Sha  = $null
        }
      }
    } else {
      $Task.Log("The manifests for the last version ${LastManifestVersion} will be overrided. Reason: ${RemoveLastVersionReason}", 'Info')
    }
  }

  # Build a new tree from the above changes
  $Task.Log('Building a Git tree', 'Verbose')
  $TreeObject = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/trees" -Method Post -Body @{
    tree      = @(
      $FileList | ForEach-Object -Process {
        @{
          path = $_.Path
          mode = '100644'
          type = 'blob'
          sha  = $_.Sha
        }
      }
    )
    base_tree = $NewRefObject.object.sha
  }

  # Create a new commit from the tree
  $Task.Log('Creating a commit', 'Verbose')
  $CommitObject = Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/commits" -Method Post -Body @{
    tree    = $TreeObject.sha
    message = $CommitName
    parents = @($NewRefObject.object.sha)
  }

  # Move the HEAD of the branch to the commit
  $Task.Log('Moving the HEAD to the commit', 'Verbose')
  Invoke-GitHubApi -Uri "https://api.github.com/repos/${OriginOwner}/${OriginRepo}/git/refs/heads/${BranchName}" -Method Post -Body @{
    sha = $CommitObject.sha
  } | Out-Null
  #endregion

  #region Create a pull request in the upstream repository
  $Task.Log('Creating a pull request', 'Info')
  if (Test-Path Env:\GITHUB_ACTIONS) {
    $NewPRBody = @"
Created by [🥟 Dumplings](https://github.com/${Env:GITHUB_REPOSITORY_OWNER}/Dumplings) in workflow run [#${Env:GITHUB_RUN_NUMBER}](https://github.com/${Env:GITHUB_REPOSITORY_OWNER}/Dumplings/actions/runs/${Env:GITHUB_RUN_ID}).

<details>

<summary>Log</summary>

````````
$($Task.Logs -join "`n")
````````

</details>

"@
  } else {
    # Here we assume that the Dumplings repository is under the same user as the winget-pkgs repository
    $NewPRBody = "Created by [🥟 Dumplings](https://github.com/${OriginOwner}/Dumplings)."
  }
  $NewPRObject = Invoke-GitHubApi -Uri "https://api.github.com/repos/${UpstreamOwner}/${UpstreamRepo}/pulls" -Method Post -Body @{
    title = $CommitName
    body  = $NewPRBody
    head  = "${OriginOwner}:${BranchName}"
    base  = 'master'
  }

  $Task.Log("Pull request created: $($NewPRObject.title) - $($NewPRObject.html_url)", 'Info')
  #endregion
}
