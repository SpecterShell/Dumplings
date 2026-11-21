# SPDX-License-Identifier: MIT
#requires -Version 7.4
# Source references: https://github.com/microsoft/winget-pkgs/blob/master/doc/Validation.md
# https://github.com/microsoft/winget-pkgs/blob/master/.github/workflows/transient-security-explanation.md
# Historical runs use the public shine-oss Azure Pipeline artifact APIs.

<#
.SYNOPSIS
  Download WinGet validation artifacts for a winget-pkgs pull request.
.DESCRIPTION
  Resolves production-validator checks on the current PR head and downloads the
  combined artifact ZIP from the completion check's WinGet CDN link. Saves check
  metadata without credentials or the download URL. Falls back to the wingetbot
  Azure comment only when that head has no production-validator checks. All
  remote operations are read-only; archives are never executed.
.PARAMETER PullRequest
  Pull request number in Repository.
.PARAMETER PipelineUrl
  wingetbot Azure Pipeline URL containing a buildId query parameter.
.PARAMETER BuildId
  Azure Pipeline build ID.
.PARAMETER Repository
  GitHub owner/repository containing the pull request.
.PARAMETER ArtifactName
  Artifacts to retrieve for historical Azure runs only. Current checks expose
  one combined ZIP containing the available logs and validation results.
.PARAMETER OutputDirectory
  Destination directory. Defaults to winget-validation-<operationId or buildId>.
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
    ConnectionTimeoutSeconds = 15
    OperationTimeoutSeconds = 60
    MaximumRetryCount = 0
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
    [ValidateRange(0, 10)][int]$MaximumRedirection = 5,
    [ValidateRange(0, 10)][int]$RetryCount = 2,
    [ValidateRange(0, 300)][int]$RetryDelaySeconds = 5
  )

  for ($Attempt = 0; $Attempt -le $RetryCount; $Attempt++) {
    try {
      Invoke-WebRequest -Uri $Uri -Headers $Headers -OutFile $OutFile -MaximumRedirection $MaximumRedirection -ConnectionTimeoutSeconds 15 -OperationTimeoutSeconds 120 -MaximumRetryCount 0 -ErrorAction Stop
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

function Get-WinGetCheckArtifact {
  <#
  .SYNOPSIS
    Resolve trusted completion metadata for the current PR head.
  .PARAMETER Number
    Pull request number; also binds the operation and artifact identity.
  .PARAMETER TargetRepository
    GitHub owner/repository. Credentials are sent only to api.github.com.
  .PARAMETER Token
    Optional GitHub token used only for read-only API requests.
  .OUTPUTS
    Check, inventory, and operation evidence; null only for historical heads.
  #>
  param (
    [Parameter(Mandatory)][int]$Number,
    [Parameter(Mandatory)][string]$TargetRepository,
    [AllowNull()][string]$Token
  )

  $Headers = Get-WinGetGitHubHeader -Token $Token
  $Pull = Invoke-WinGetJsonRequest -Method Get -Uri "https://api.github.com/repos/$TargetRepository/pulls/$Number" -Headers $Headers
  $HeadSha = [string]$Pull.head.sha
  if ($HeadSha -notmatch '^[0-9a-f]{40}$') { throw 'GitHub did not return a valid PR head SHA.' }
  $Checks = [Collections.Generic.List[object]]::new()
  for ($Page = 1; ; $Page++) {
    if ($Page -gt 100) { throw 'The check-run pagination limit was exceeded.' }
    $Response = Invoke-WinGetJsonRequest -Method Get -Uri "https://api.github.com/repos/$TargetRepository/commits/$HeadSha/check-runs?app_id=1451866&filter=all&per_page=100&page=$Page" -Headers $Headers
    foreach ($Check in $Response.check_runs) {
      if ($Check.app.id -eq 1451866 -and $Check.app.slug -ceq 'wingetvalidator-prod' -and $Check.head_sha -ceq $HeadSha) { $Checks.Add($Check) }
    }
    if (@($Response.check_runs).Count -lt 100) { break }
  }
  if ($Checks.Count -eq 0) { return $null }

  # A newer queued/in-progress operation must not fall back to old passing logs.
  $Latest = $Checks | Sort-Object id -Descending | Select-Object -First 1
  $OperationId = [string]$Latest.external_id
  if ($OperationId -notmatch "^WinGetSvc-Validation-$Number-[0-9]+$") { throw 'The validator returned an unexpected operation identity.' }
  $OperationChecks = @($Checks | Where-Object external_id -CEQ $OperationId | Sort-Object name, id)
  $Completion = $OperationChecks | Where-Object name -CEQ '10. Validation Completed' | Sort-Object id -Descending | Select-Object -First 1
  if ($null -eq $Completion -or $Completion.status -ne 'completed') { throw "Validation operation $OperationId has not completed; current artifacts are unavailable." }
  $Blocks = [regex]::Matches([string]$Completion.output.text, '(?im)^```json\s*\r?\n([\s\S]*?)^```\s*$')
  if ($Blocks.Count -ne 1) { throw 'The completion check must contain exactly one JSON artifact record.' }
  $Payload = $Blocks[0].Groups[1].Value | ConvertFrom-Json -AsHashtable
  $Artifact = $Payload['Artifacts']
  if ($Artifact -isnot [Collections.IDictionary]) { throw "Validation operation $OperationId did not publish downloadable artifact metadata." }
  if ($Payload.PullRequestNumber -ne $Number -or $Payload.OperationId -cne $OperationId -or $Artifact.OperationId -cne $OperationId -or $Artifact.ZipFileName -cne "$OperationId-artifacts.zip") {
    throw 'The artifact metadata does not match the PR validation operation.'
  }
  $Uri = [uri]$Artifact.ArtifactDownloadUrl
  if (-not $Uri.IsAbsoluteUri -or $Uri.Scheme -ne 'https' -or $Uri.Host -ine 'cdn.winget.microsoft.com' -or -not $Uri.IsDefaultPort -or $Uri.UserInfo -or $Uri.Query -or $Uri.Fragment -or $Uri.AbsolutePath -cne "/artifacts/$($Artifact.ZipFileName)") {
    throw 'The artifact URL is not a supported WinGet CDN artifact URL.'
  }
  if ($Artifact.ArtifactDownloadUrlExpiresOn -and [datetimeoffset]$Artifact.ArtifactDownloadUrlExpiresOn -le [datetimeoffset]::UtcNow) {
    throw "Artifacts for $OperationId have expired; preserve the check result and report the missing logs."
  }
  $Entries = @($Artifact.InstallationLogs) + @($Artifact.ValidationResults)
  if ($Artifact.ZipFileSizeBytes -le 0 -or $Artifact.ZipFileSizeBytes -gt 1GB -or $Artifact.TotalFilesCount -ne $Entries.Count -or $Entries.Count -gt 10000 -or $Artifact.TotalSizeBytes -lt 0 -or $Artifact.TotalSizeBytes -gt 1GB) {
    throw 'The artifact inventory has invalid or excessive sizes/counts.'
  }
  $Inventory = [Collections.Generic.Dictionary[string, long]]::new([StringComparer]::OrdinalIgnoreCase)
  [long]$TotalBytes = 0
  foreach ($Entry in $Entries) {
    $Name = [string]$Entry.RelativePath
    if (-not $Name -or $Name -match '[\\:]|(^|/)[.]{1,2}(/|$)|^/|//$' -or $Entry.FileName -cne ($Name.Split('/')[-1]) -or $Entry.SizeBytes -lt 0 -or $Entry.SizeBytes -gt 1GB -or $Inventory.ContainsKey($Name)) {
      throw 'The artifact inventory contains an unsafe, duplicate, or invalid entry.'
    }
    $Inventory.Add($Name, [long]$Entry.SizeBytes)
    $TotalBytes += [long]$Entry.SizeBytes
  }
  if ($TotalBytes -ne $Artifact.TotalSizeBytes) { throw 'The artifact inventory byte total is inconsistent.' }
  # Keep operational evidence, but never persist the download URL or API token.
  $Artifact.Remove('ArtifactDownloadUrl')
  $Metadata = [ordered]@{
    Source = 'GitHubCheckRun'; PullRequest = $Number; Repository = $TargetRepository
    HeadSha = $HeadSha; OperationId = $OperationId; CheckRunId = $Completion.id
    CheckUrl = $Completion.html_url; Artifacts = $Artifact
    Checks = @($OperationChecks | Select-Object id, name, status, conclusion, external_id, completed_at)
  }
  return [pscustomobject]@{ Metadata = $Metadata; DownloadUri = $Uri; Inventory = $Inventory }
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
    [Parameter(Mandatory)][string]$DestinationPath,
    [Collections.Generic.Dictionary[string, long]]$Inventory
  )

  $Root = [IO.Path]::GetFullPath($DestinationPath).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  $Archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
  try {
    # Preflight every entry before removing prior evidence or writing any content.
    if ($Archive.Entries.Count -gt 10000) { throw 'The artifact ZIP exceeds the entry-count limit.' }
    $Paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    [long]$TotalBytes = 0
    foreach ($Entry in $Archive.Entries) {
      $Name = $Entry.FullName.Replace('\', '/')
      $Target = [IO.Path]::GetFullPath((Join-Path $Root $Name))
      if ($Name -match ':|(^|/)[.]{1,2}(/|$)|^/' -or -not $Target.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase) -or -not $Paths.Add($Target) -or (($Entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) {
        throw 'The artifact ZIP contains an unsafe or duplicate path.'
      }
      if ($Name.EndsWith('/')) { continue }
      $TotalBytes += $Entry.Length
      if ($Entry.Length -gt 1GB -or $TotalBytes -gt 1GB -or $Paths.Count -gt 10000) { throw 'The artifact ZIP exceeds extraction limits.' }
      if ($null -ne $Inventory -and (-not $Inventory.ContainsKey($Name) -or $Inventory[$Name] -ne $Entry.Length)) { throw 'The artifact ZIP does not match its declared inventory.' }
    }
    if ($null -ne $Inventory -and @($Archive.Entries | Where-Object { -not $_.FullName.EndsWith('/') }).Count -ne $Inventory.Count) { throw 'The artifact ZIP is missing declared files.' }
    if (Test-Path -LiteralPath $DestinationPath) {
      if (-not $Force) { throw "Artifact destination already exists: $DestinationPath. Use -Force to replace it." }
      $OutputRoot = [IO.Path]::GetFullPath($OutputDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
      if (-not $Root.StartsWith($OutputRoot, [StringComparison]::OrdinalIgnoreCase) -or $Root -eq $OutputRoot) { throw 'The extraction destination must be a child of the output directory.' }
      Remove-Item -LiteralPath $DestinationPath -Recurse -Force
    }
    $Buffer = [byte[]]::new(65536)
    foreach ($Entry in $Archive.Entries) {
      $Target = Join-Path $Root $Entry.FullName
      if ($Entry.FullName.EndsWith('/')) { $null = [IO.Directory]::CreateDirectory($Target); continue }
      $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Target))
      $Source = $Entry.Open()
      try {
        $Destination = [IO.File]::Open($Target, [IO.FileMode]::CreateNew)
        try {
          [long]$Written = 0
          while (($Count = $Source.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
            $Written += $Count
            if ($Written -gt $Entry.Length) { throw 'The artifact entry exceeds its advertised length.' }
            $Destination.Write($Buffer, 0, $Count)
          }
          if ($Written -ne $Entry.Length) { throw 'The artifact entry is truncated.' }
        } finally { $Destination.Dispose() }
      } finally { $Source.Dispose() }
    }
  } finally { $Archive.Dispose() }
}

# Current PRs use one CDN ZIP. Keep the Azure route below for historical inputs.
if ($PSCmdlet.ParameterSetName -eq 'PullRequest') {
  $Current = Get-WinGetCheckArtifact -Number $PullRequest -TargetRepository $Repository -Token $GitHubToken
  if ($null -ne $Current) {
    $Metadata = $Current.Metadata
    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $PWD "winget-validation-$($Metadata.OperationId)" }
    $OutputDirectory = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
    $ArchivePath = Join-Path $OutputDirectory $Metadata.Artifacts.ZipFileName
    $ExtractedPath = Join-Path $OutputDirectory $Metadata.OperationId
    $MetadataPath = Join-Path $OutputDirectory 'validation-check.json'
    foreach ($Path in $ArchivePath, $MetadataPath, $ExtractedPath) {
      if ((Test-Path -LiteralPath $Path) -and -not $Force) { throw "Artifact output already exists: $Path. Use -Force to replace it." }
    }
    if ($PSCmdlet.ShouldProcess($OutputDirectory, "Download validation operation $($Metadata.OperationId)")) {
      $null = [IO.Directory]::CreateDirectory($OutputDirectory)
      # Disallow redirects and deliberately omit Authorization on the CDN request.
      Invoke-WinGetFileRequest -Uri $Current.DownloadUri -OutFile $ArchivePath -Headers @{ 'User-Agent' = $UserAgent } -MaximumRedirection 0
      if ((Get-Item -LiteralPath $ArchivePath).Length -ne $Metadata.Artifacts.ZipFileSizeBytes) { throw 'The downloaded artifact ZIP has an unexpected length.' }
      [IO.File]::WriteAllText($MetadataPath, ($Metadata | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
      if (-not $NoExpand) { Expand-WinGetValidationArtifact -ArchivePath $ArchivePath -DestinationPath $ExtractedPath -Inventory $Current.Inventory }
    }
    [pscustomobject][ordered]@{
      Source = $Metadata.Source; PullRequest = $PullRequest; HeadSha = $Metadata.HeadSha
      OperationId = $Metadata.OperationId; CheckRunId = $Metadata.CheckRunId
      Status = if ($WhatIfPreference) { 'WhatIf' } else { 'Downloaded' }
      ArchivePath = $ArchivePath; ExtractedPath = if ($NoExpand) { $null } else { $ExtractedPath }; MetadataPath = $MetadataPath
    }
    return
  }
}

$ResolvedPullRequest = $null
$ResolvedPipelineUrl = $null
$ResolvedBuildId = $null
switch ($PSCmdlet.ParameterSetName) {
  'PullRequest' {
    Write-Warning 'No production-validator checks exist on the current PR head; retrieving historical Azure evidence, which may refer to an older commit.'
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
$OutputDirectory = $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if ($PSCmdlet.ShouldProcess($OutputDirectory, 'Create validation artifact output directory')) {
  $null = [IO.Directory]::CreateDirectory($OutputDirectory)
}

$DownloadedCount = 0
$Results = foreach ($Artifact in Get-WinGetBuildArtifact -ResolvedBuildId $ResolvedBuildId -RequestedArtifactName $ArtifactName) {
  $DownloadUri = Get-WinGetArtifactDownloadUri -ResolvedBuildId $ResolvedBuildId -Artifact $Artifact
  if ($null -eq $DownloadUri) {
    Write-Warning "Build $ResolvedBuildId did not expose artifact $($Artifact.Name)."
    [pscustomobject][ordered]@{
      Source = 'AzureDevOps'
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
    Source = 'AzureDevOps'
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
