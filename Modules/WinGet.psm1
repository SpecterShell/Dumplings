#Requires -Version 7.4

# Apply default function parameters
if ($DumplingsDefaultParameterValues) { $PSDefaultParameterValues = $DumplingsDefaultParameterValues }

# Force stop on error
$ErrorActionPreference = 'Stop'
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'PSNativeCommandUseErrorActionPreference', Justification = 'This is a built-in variable of PowerShell')]
$PSNativeCommandUseErrorActionPreference = $true

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
} elseif (Test-Path Variable:\DumplingsRoot) {
  $ManifestsFolder = Join-Path $Global:DumplingsRoot '..' $UpstreamRepo 'manifests' -Resolve
} else {
  $ManifestsFolder = Join-Path $PSScriptRoot '..' '..' $UpstreamRepo 'manifests' -Resolve
}

# Prepare origin ref
try {
  $BaseRefSha = (Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:OriginOwner}/${Script:OriginRepo}/git/ref/heads/${Script:OriginBranch}").object.sha
} catch {
  Write-Log -Object 'Failed to fetch the SHA of the base branch. Will try again later' -Identifier 'WinGet' -Level Warning
  $_ | Out-Host
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
  $PackageIdentifier = $Task.Config.WinGetIdentifier
  $PackageVersion = $Task.CurrentState.Contains('RealVersion') ? $Task.CurrentState.RealVersion : $Task.CurrentState.Version
  $PackageLastVersion = $Task.LastState.Contains('RealVersion') ? $Task.LastState.RealVersion : $Task.LastState.Version

  $BranchName = "${PackageIdentifier}-${PackageVersion}-$(Get-Random)" -replace '[\~,\^,\:,\\,\?,\@\{,\*,\[,\s]{1,}|[.lock|/|\.]*$|^\.{1,}|\.\.', ''
  $CommitType = if ($Task.LastState.Contains('Version')) {
    switch (Compare-Version -ReferenceVersion $PackageLastVersion -DifferenceVersion $PackageVersion) {
      1 { 'New version' }
      0 { 'Update' }
      -1 { 'Add version' }
    }
  } else {
    'New version'
  }
  $CommitName = "${CommitType}: ${PackageIdentifier} version ${PackageVersion}"
  if ($Task.CurrentState.Contains('RealVersion')) { $CommitName += " ($($Task.CurrentState.Version))" }

  $OutFolder = (New-Item -Path (Join-Path $Global:LocalCache $PackageIdentifier $PackageVersion) -ItemType Directory -Force).FullName
  #endregion

  #region Check existing pull requests in the upstream repository
  $Task.Log('Checking existing pull requests', 'Verbose')

  $OldPRObject = Invoke-GitHubApi -Uri "https://api.github.com/search/issues?q=repo:${Script:UpstreamOwner}/${Script:UpstreamRepo} is:pr $($PackageIdentifier.Replace('.', '/'))/${PackageVersion} in:path&per_page=1"
  if ($OldPRObject.total_count -gt 0) {
    if (-not ($Global:DumplingsPreference.Contains('NoCheck') -and $Global:DumplingsPreference.NoCheck) -and -not ($Task.Config.Contains('IgnorePRCheck') -and $Task.Config.IgnorePRCheck)) {
      throw "Existing pull request found: $($OldPRObject.items[0].title) - $($OldPRObject.items[0].html_url)"
    } else {
      $Task.Log("Existing pull request found: $($OldPRObject.items[0].title) - $($OldPRObject.items[0].html_url)", 'Warning')
    }
  }
  #endregion

  #region Create manifests using YamlCreate
  $Task.Log('Creating manifests', 'Verbose')

  try {
    $Parameters = @{
      PackageIdentifier = $PackageIdentifier
      PackageVersion    = $PackageVersion
      PackageInstallers = $Task.CurrentState.Installer
      Locales           = $Task.CurrentState.Locale
      ManifestsFolder   = $Script:ManifestsFolder
      OutFolder         = $OutFolder
    }
    if ($Task.CurrentState.ReleaseTime) {
      if ($Task.CurrentState.ReleaseTime -is [datetime] -or $Task.CurrentState.ReleaseTime -is [System.DateTimeOffset]) {
        $Parameters.PackageReleaseDate = $Task.CurrentState.ReleaseTime.ToUniversalTime().ToString('yyyy-MM-dd')
      } else {
        $Parameters.PackageReleaseDate = $Task.CurrentState.ReleaseTime | Get-Date -Format 'yyyy-MM-dd'
      }
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

  $WinGetOutput = ''
  try {
    winget validate $OutFolder | Out-String -Stream -OutVariable 'WinGetOutput'
  } catch {
    if ($_.FullyQualifiedErrorId -eq 'CommandNotFoundException') {
      $Task.Log('Could not find WinGet client for validating manifests. Is it installed and added to PATH?', 'Error')
      throw $_
    } elseif ($_.FullyQualifiedErrorId -eq 'ProgramExitedWithNonZeroCode' -and $_.Exception.ExitCode -ne -1978335192) {
      # WinGet may throw warnings for, for example, not specifying the installer switches for EXE installers
      # Ignore these warnings by checking the exit code as it actually doesn't matter
      $Task.Log('Failed to pass the validation', 'Error')
      throw ($WinGetOutput -join "`n")
    } elseif ($_.FullyQualifiedErrorId -ne 'ProgramExitedWithNonZeroCode') {
      $Task.Log('Failed to validate', 'Error')
      throw $_
    }
  }

  $Task.Log('Manifests validation passed', 'Verbose')
  #endregion

  #region Upload new manifests, remove old manifests if needed, and commit in the origin repository
  $Task.Log('Uploading manifests and committing', 'Verbose')

  # Create a new branch
  # The new branch is created from the default branch of the origin repo rather than the one of the upstream repo
  # This is to mitigate the occasional and weird issue of "ref not found" when creating a new branch from the default branch of the upstream repo
  # The origin repo should be synced as early as possible to avoid conflicts with other commits
  try {
    $Script:BaseRefSha ??= (Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:OriginOwner}/${Script:OriginRepo}/git/ref/heads/${Script:OriginBranch}").object.sha
    $NewRefObject = Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:OriginOwner}/${Script:OriginRepo}/git/refs" -Method Post -Body @{
      ref = "refs/heads/${BranchName}"
      sha = $Script:BaseRefSha
    }
  } catch {
    $Task.Log('Failed to create branch', 'Error')
    throw $_
  }

  # Upload new manifests
  try {
    $FilePathSha = @()
    Get-ChildItem -Path $OutFolder -Include '*.yaml' -Recurse -File | ForEach-Object -Process {
      $NewFileObject = Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:OriginOwner}/${Script:OriginRepo}/git/blobs" -Method Post -Body @{
        content  = Get-Content -Path $_ -Raw -Encoding utf8NoBOM
        encoding = 'utf-8'
      }
      $FilePathSha += @{
        Path = "manifests/$($PackageIdentifier.ToLower().Chars(0))/$($PackageIdentifier.Replace('.', '/'))/${PackageVersion}/$($_.Name)"
        Sha  = $NewFileObject.sha
      }
    }
    if ($FilePathSha.Count -eq 0) {
      throw 'Could not find any file to be uploaded'
    }
  } catch {
    $Task.Log('Failed to upload files', 'Error')
    throw $_
  }

  # Remove old manifests, if needed
  try {
    if ($Task.Config.Contains('RemoveLastVersion') -and $Task.Config.RemoveLastVersion) {
      $LastManifestVersion = Get-ChildItem -Path "${Script:ManifestsFolder}\$($PackageIdentifier.ToLower().Chars(0))\$($PackageIdentifier.Replace('.', '\'))\*\${PackageIdentifier}.yaml" -File |
        Split-Path -Parent | Split-Path -Leaf |
        Sort-Object { [regex]::Replace($_, '\d+', { $args[0].Value.PadLeft(20) }) } -Culture en-US | Select-Object -Last 1
      if ($LastManifestVersion -ne $PackageVersion) {
        $Task.Log("The manifests for the last version ${LastManifestVersion} will be removed", 'Info')
        Get-ChildItem -Path "${Script:ManifestsFolder}\$($PackageIdentifier.ToLower().Chars(0))\$($PackageIdentifier.Replace('.', '\'))\${LastManifestVersion}\*.yaml" -File | ForEach-Object -Process {
          $FilePathSha += @{
            Path = "manifests/$($PackageIdentifier.ToLower().Chars(0))/$($PackageIdentifier.Replace('.', '/'))/${LastManifestVersion}/$($_.Name)"
            Sha  = $null
          }
        }
      } else {
        $Task.Log("The manifests for the last version ${LastManifestVersion} will be overrided", 'Info')
      }
    }
  } catch {
    $Task.Log('Failed to remove files', 'Error')
    throw $_
  }

  # Build a new tree from the above changes
  try {
    $TreeObject = Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:OriginOwner}/${Script:OriginRepo}/git/trees" -Method Post -Body @{
      tree      = @(
        $FilePathSha | ForEach-Object -Process {
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
  } catch {
    $Task.Log('Failed to build tree', 'Error')
    throw $_
  }

  # Create a new commit from the tree
  try {
    $CommitObject = Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:OriginOwner}/${Script:OriginRepo}/git/commits" -Method Post -Body @{
      tree    = $TreeObject.sha
      message = $CommitName
      parents = @($NewRefObject.object.sha)
    }
  } catch {
    $Task.Log('Failed to create commit', 'Error')
    throw $_
  }

  # Move the HEAD of the branch to the commit
  try {
    Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:OriginOwner}/${Script:OriginRepo}/git/refs/heads/${BranchName}" -Method Post -Body @{
      sha = $CommitObject.sha
    } | Out-Null
  } catch {
    $Task.Log('Failed to opearate branch', 'Error')
    throw $_
  }

  $Task.Log('Manifests uploaded and committed', 'Verbose')
  #endregion

  #region Create pull request in the upstream repository
  $Task.Log('Creating pull request', 'Verbose')

  try {
    if (Test-Path Env:\CI) {
      $NewPRBody = "Created by [🥟 Dumplings](https://github.com/SpecterShell/Dumplings) in Run [#${Env:GITHUB_RUN_NUMBER}](https://github.com/${Script:OriginOwner}/Dumplings/actions/runs/${Env:GITHUB_RUN_ID})."
    } else {
      $NewPRBody = 'Created by [🥟 Dumplings](https://github.com/SpecterShell/Dumplings).'
    }
    $NewPRObject = Invoke-GitHubApi -Uri "https://api.github.com/repos/${Script:UpstreamOwner}/${Script:UpstreamRepo}/pulls" -Method Post -Body @{
      title = $CommitName
      body  = $NewPRBody
      head  = "${Script:OriginOwner}:${BranchName}"
      base  = 'master'
    }
  } catch {
    $Task.Log('Failed to create pull request', 'Error')
    throw $_
  }

  $Task.Log("Pull request created: $($NewPRObject.html_url)", 'Info')
  #endregion
}
