# SPDX-License-Identifier: MIT
# Workflow reference: microsoft/winget-pkgs validation comments and the public
# shine-oss Azure Pipeline artifact APIs used by wingetbot.

<#
.SYNOPSIS
  Download WinGet validation artifacts for a winget-pkgs pull request.
.DESCRIPTION
  Resolves the latest wingetbot Validation Pipeline Run comment, locates the
  InstallationVerificationLogs and ValidationResult Azure artifacts, downloads
  their ZIP archives, and expands them locally. This script is read-only with
  respect to GitHub and Azure DevOps.
.PARAMETER PullRequest
  Pull request number in Repository.
.PARAMETER PipelineUrl
  wingetbot Azure Pipeline URL containing a buildId query parameter.
.PARAMETER BuildId
  Azure Pipeline build ID.
.PARAMETER Repository
  GitHub owner/repository containing the pull request.
.PARAMETER ArtifactName
  Validation artifacts to retrieve.
.PARAMETER OutputDirectory
  Destination directory. Defaults to winget-validation-<buildId>.
.PARAMETER GitHubToken
  Optional GitHub token. Anonymous access is sufficient for public PRs but is
  rate limited. Defaults to GH_DUMPLINGS_TOKEN, matching the Dumplings GitHub
  API helpers.
.PARAMETER NoExpand
  Keep downloaded ZIP files without expanding them.
.PARAMETER Force
  Replace existing archives and extracted artifact directories.
#>
[CmdletBinding(DefaultParameterSetName = 'PullRequest', SupportsShouldProcess, ConfirmImpact = 'Low')]
param (
  [Parameter(Mandatory, ParameterSetName = 'PullRequest', Position = 0)]
  [ValidateRange(1, [int]::MaxValue)]
  [int]$PullRequest,

  [Parameter(Mandatory, ParameterSetName = 'PipelineUrl')]
  [uri]$PipelineUrl,

  [Parameter(Mandatory, ParameterSetName = 'BuildId')]
  [ValidateRange(1, [int]::MaxValue)]
  [int]$BuildId,

  [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
  [string]$Repository = 'microsoft/winget-pkgs',

  [ValidateSet('InstallationVerificationLogs', 'ValidationResult')]
  [string[]]$ArtifactName = @('InstallationVerificationLogs', 'ValidationResult'),

  [string]$OutputDirectory,

  [string]$GitHubToken = $env:GH_DUMPLINGS_TOKEN,

  [switch]$NoExpand,

  [switch]$Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

$AzureOrganization = 'shine-oss'
$AzureProject = 'winget-pkgs'
$AzureProjectId = '8b78618a-7973-49d8-9174-4360829d979b'
$AzureContribution = 'ms.vss-build-web.run-artifacts-download-data-provider'
$UserAgent = 'Dumplings-WinGet-Validation-Log'
$PipelineCommentPattern = 'Validation Pipeline Run\s+\[[^\]]+\]\((?<Url>https://dev\.azure\.com/shine-oss/[^)\s]*?_build/results\?[^)]*?buildId=(?<BuildId>\d+)[^)]*)\)'

function Invoke-WinGetJsonRequest {
  param (
    [Parameter(Mandatory)][ValidateSet('Get', 'Post')][string]$Method,
    [Parameter(Mandatory)][uri]$Uri,
    [hashtable]$Headers = @{},
    [AllowNull()][object]$Body,
    [ValidateRange(0, 10)][int]$RetryCount = 2,
    [ValidateRange(0, 300)][int]$RetryDelaySeconds = 5
  )

  $Parameters = @{
    Method = $Method
    Uri = $Uri
    Headers = $Headers
    ErrorAction = 'Stop'
  }
  if ($PSBoundParameters.ContainsKey('Body')) {
    $Parameters.Body = $Body | ConvertTo-Json -Depth 12
    $Parameters.ContentType = 'application/json'
  }

  for ($Attempt = 0; $Attempt -le $RetryCount; $Attempt++) {
    try {
      return Invoke-RestMethod @Parameters
    } catch {
      if ($Attempt -ge $RetryCount) { throw }
      Start-Sleep -Seconds $RetryDelaySeconds
    }
  }
}

function Invoke-WinGetFileRequest {
  param (
    [Parameter(Mandatory)][uri]$Uri,
    [Parameter(Mandatory)][string]$OutFile,
    [hashtable]$Headers = @{},
    [ValidateRange(0, 10)][int]$RetryCount = 2,
    [ValidateRange(0, 300)][int]$RetryDelaySeconds = 5
  )

  for ($Attempt = 0; $Attempt -le $RetryCount; $Attempt++) {
    try {
      Invoke-WebRequest -Uri $Uri -Headers $Headers -OutFile $OutFile -ErrorAction Stop
      return
    } catch {
      if ($Attempt -ge $RetryCount) { throw }
      Start-Sleep -Seconds $RetryDelaySeconds
    }
  }
}

function Get-WinGetGitHubHeader {
  param ([AllowNull()][string]$Token)

  $Headers = @{
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
    'User-Agent' = $UserAgent
  }
  if (-not [string]::IsNullOrWhiteSpace($Token)) {
    $Headers.Authorization = "Bearer $Token"
  }
  return $Headers
}

function Get-WinGetPullRequestComment {
  param (
    [Parameter(Mandatory)][int]$Number,
    [Parameter(Mandatory)][string]$TargetRepository,
    [AllowNull()][string]$Token
  )

  $Headers = Get-WinGetGitHubHeader -Token $Token
  for ($Page = 1; ; $Page++) {
    $Uri = "https://api.github.com/repos/$TargetRepository/issues/$Number/comments?per_page=100&page=$Page"
    $Comments = @(Invoke-WinGetJsonRequest -Method Get -Uri $Uri -Headers $Headers)
    foreach ($Comment in $Comments) { $Comment }
    if ($Comments.Count -lt 100) { break }
  }
}

function Get-WinGetPipelineComment {
  param (
    [Parameter(Mandatory)][int]$Number,
    [Parameter(Mandatory)][string]$TargetRepository,
    [AllowNull()][string]$Token
  )

  $PipelineComments = foreach ($Comment in Get-WinGetPullRequestComment -Number $Number -TargetRepository $TargetRepository -Token $Token) {
    if ([string]$Comment.user.login -ine 'wingetbot') { continue }
    $Match = [regex]::Match([string]$Comment.body, $PipelineCommentPattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $Match.Success) { continue }
    [pscustomobject][ordered]@{
      CommentId = [int64]$Comment.id
      CreatedAt = [datetimeoffset]$Comment.created_at
      BuildId = [int]$Match.Groups['BuildId'].Value
      PipelineUrl = [uri]$Match.Groups['Url'].Value
    }
  }
  $Latest = $PipelineComments | Sort-Object CreatedAt, CommentId -Descending | Select-Object -First 1
  if ($null -eq $Latest) { throw "PR #$Number has no wingetbot Validation Pipeline Run comment." }
  return $Latest
}

function Get-WinGetJsonObject {
  param ([AllowNull()][object]$InputObject)

  if ($null -eq $InputObject -or $InputObject -is [string]) { return }
  if ($InputObject -is [Collections.IDictionary] -or $InputObject -is [pscustomobject]) {
    $InputObject
    foreach ($Property in $InputObject.PSObject.Properties) {
      Get-WinGetJsonObject -InputObject $Property.Value
    }
    return
  }
  if ($InputObject -is [Collections.IEnumerable]) {
    foreach ($Item in $InputObject) { Get-WinGetJsonObject -InputObject $Item }
  }
}

function Get-WinGetArtifactPageUri {
  param (
    [Parameter(Mandatory)][int]$ResolvedBuildId,
    [switch]$Fps
  )

  $Uri = "https://dev.azure.com/$AzureOrganization/$AzureProject/_build/results?buildId=$ResolvedBuildId&view=artifacts&pathAsName=false&type=publishedArtifacts"
  if ($Fps) { $Uri += '&__rt=fps&__ver=2' }
  return [uri]$Uri
}

function Get-WinGetBuildArtifact {
  param (
    [Parameter(Mandatory)][int]$ResolvedBuildId,
    [Parameter(Mandatory)][string[]]$RequestedArtifactName
  )

  $ArtifactMap = @{}
  foreach ($Name in $RequestedArtifactName) {
    $ArtifactMap[$Name] = [pscustomobject][ordered]@{ Name = $Name; ArtifactId = $null; DownloadUrl = $null }
  }

  $ArtifactPage = Invoke-WinGetJsonRequest -Method Get -Uri (Get-WinGetArtifactPageUri -ResolvedBuildId $ResolvedBuildId -Fps) -Headers @{ Accept = 'application/json'; 'User-Agent' = $UserAgent }
  foreach ($Object in Get-WinGetJsonObject -InputObject $ArtifactPage) {
    $NameProperty = $Object.PSObject.Properties['name']
    $IdProperty = $Object.PSObject.Properties['artifactId']
    if (-not $NameProperty -or -not $IdProperty) { continue }
    $Name = [string]$NameProperty.Value
    if ($ArtifactMap.ContainsKey($Name) -and $null -ne $IdProperty.Value) {
      $ArtifactMap[$Name].ArtifactId = [int]$IdProperty.Value
    }
  }

  if (@($ArtifactMap.Values | Where-Object { $null -eq $_.ArtifactId }).Count -gt 0) {
    $ApiUri = "https://dev.azure.com/$AzureOrganization/$AzureProject/_apis/build/builds/$ResolvedBuildId/artifacts?api-version=7.1"
    $ApiResult = Invoke-WinGetJsonRequest -Method Get -Uri $ApiUri -Headers @{ 'User-Agent' = $UserAgent }
    foreach ($Item in @($ApiResult.value)) {
      $Name = [string]$Item.name
      if (-not $ArtifactMap.ContainsKey($Name)) { continue }
      if ($null -ne $Item.id) { $ArtifactMap[$Name].ArtifactId = [int]$Item.id }
      if ($Item.resource -and $Item.resource.downloadUrl) { $ArtifactMap[$Name].DownloadUrl = [uri]$Item.resource.downloadUrl }
    }
  }

  return @($RequestedArtifactName | ForEach-Object { $ArtifactMap[$_] })
}

function Get-WinGetArtifactDownloadUri {
  param (
    [Parameter(Mandatory)][int]$ResolvedBuildId,
    [Parameter(Mandatory)]$Artifact
  )

  if ($null -eq $Artifact.ArtifactId) {
    if ($Artifact.DownloadUrl) { return [uri]$Artifact.DownloadUrl }
    return $null
  }

  $ContributionUri = "https://dev.azure.com/$AzureOrganization/_apis/Contribution/HierarchyQuery/project/$AzureProjectId"
  $Payload = [ordered]@{
    contributionIds = @($AzureContribution)
    dataProviderContext = [ordered]@{
      properties = [ordered]@{
        artifactId = [int]$Artifact.ArtifactId
        buildId = $ResolvedBuildId
        compressDownload = $true
        path = ''
        saveAbsolutePath = $true
        sourcePage = [ordered]@{
          url = [string](Get-WinGetArtifactPageUri -ResolvedBuildId $ResolvedBuildId)
          routeId = 'ms.vss-build-web.ci-results-hub-route'
          routeValues = [ordered]@{
            project = $AzureProject
            viewname = 'build-results'
            controller = 'ContributedPage'
            action = 'Execute'
          }
        }
      }
    }
  }
  $Headers = @{
    Accept = 'application/json;api-version=5.0-preview.1;excludeUrls=true;enumsAsNumbers=true;msDateFormat=true;noArrayWrap=true'
    'User-Agent' = $UserAgent
  }
  $Result = Invoke-WinGetJsonRequest -Method Post -Uri $ContributionUri -Headers $Headers -Body $Payload
  $Provider = $Result.dataProviders.PSObject.Properties[$AzureContribution]
  if ($Provider -and $Provider.Value.downloadUrl) { return [uri]$Provider.Value.downloadUrl }
  if ($Artifact.DownloadUrl) { return [uri]$Artifact.DownloadUrl }
  return $null
}

function Expand-WinGetValidationArtifact {
  param (
    [Parameter(Mandatory)][string]$ArchivePath,
    [Parameter(Mandatory)][string]$DestinationPath
  )

  if (Test-Path -LiteralPath $DestinationPath) {
    if (-not $Force) { throw "Artifact destination already exists: $DestinationPath. Use -Force to replace it." }
    Remove-Item -LiteralPath $DestinationPath -Recurse -Force
  }
  Expand-Archive -LiteralPath $ArchivePath -DestinationPath $DestinationPath -Force
}

$ResolvedPullRequest = $null
$ResolvedPipelineUrl = $null
$ResolvedBuildId = $null
switch ($PSCmdlet.ParameterSetName) {
  'PullRequest' {
    $PipelineComment = Get-WinGetPipelineComment -Number $PullRequest -TargetRepository $Repository -Token $GitHubToken
    $ResolvedPullRequest = $PullRequest
    $ResolvedPipelineUrl = $PipelineComment.PipelineUrl
    $ResolvedBuildId = $PipelineComment.BuildId
  }
  'PipelineUrl' {
    $Match = [regex]::Match($PipelineUrl.Query, '(?:^|[?&])buildId=(?<BuildId>\d+)(?:&|$)', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $Match.Success) { throw 'PipelineUrl does not contain a numeric buildId query parameter.' }
    $ResolvedPipelineUrl = $PipelineUrl
    $ResolvedBuildId = [int]$Match.Groups['BuildId'].Value
  }
  'BuildId' {
    $ResolvedBuildId = $BuildId
    $ResolvedPipelineUrl = Get-WinGetArtifactPageUri -ResolvedBuildId $ResolvedBuildId
  }
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path $PWD "winget-validation-$ResolvedBuildId"
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
if ($PSCmdlet.ShouldProcess($OutputDirectory, 'Create validation artifact output directory')) {
  $null = [IO.Directory]::CreateDirectory($OutputDirectory)
}

$DownloadedCount = 0
$Results = foreach ($Artifact in Get-WinGetBuildArtifact -ResolvedBuildId $ResolvedBuildId -RequestedArtifactName $ArtifactName) {
  $DownloadUri = Get-WinGetArtifactDownloadUri -ResolvedBuildId $ResolvedBuildId -Artifact $Artifact
  if ($null -eq $DownloadUri) {
    Write-Warning "Build $ResolvedBuildId did not expose artifact $($Artifact.Name)."
    [pscustomobject][ordered]@{
      PullRequest = $ResolvedPullRequest
      BuildId = $ResolvedBuildId
      PipelineUrl = $ResolvedPipelineUrl
      ArtifactName = $Artifact.Name
      Status = 'Missing'
      ArchivePath = $null
      ExtractedPath = $null
    }
    continue
  }

  $ArchivePath = Join-Path $OutputDirectory "$($Artifact.Name).zip"
  $ExtractedPath = Join-Path $OutputDirectory $Artifact.Name
  if ((Test-Path -LiteralPath $ArchivePath) -and -not $Force) {
    throw "Artifact archive already exists: $ArchivePath. Use -Force to replace it."
  }

  if ($PSCmdlet.ShouldProcess($ArchivePath, "Download Azure validation artifact $($Artifact.Name)")) {
    Invoke-WinGetFileRequest -Uri $DownloadUri -OutFile $ArchivePath -Headers @{ 'User-Agent' = $UserAgent }
    $DownloadedCount++
    if (-not $NoExpand -and $PSCmdlet.ShouldProcess($ExtractedPath, "Expand Azure validation artifact $($Artifact.Name)")) {
      Expand-WinGetValidationArtifact -ArchivePath $ArchivePath -DestinationPath $ExtractedPath
    }
  }

  [pscustomobject][ordered]@{
    PullRequest = $ResolvedPullRequest
    BuildId = $ResolvedBuildId
    PipelineUrl = $ResolvedPipelineUrl
    ArtifactName = $Artifact.Name
    Status = if ($WhatIfPreference) { 'WhatIf' } else { 'Downloaded' }
    ArchivePath = $ArchivePath
    ExtractedPath = if ($NoExpand) { $null } else { $ExtractedPath }
  }
}

if (-not $WhatIfPreference -and $DownloadedCount -eq 0) {
  throw "No requested validation artifacts were downloaded for build $ResolvedBuildId."
}

$Results
