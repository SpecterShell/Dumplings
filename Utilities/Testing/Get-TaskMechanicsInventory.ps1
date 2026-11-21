#Requires -Version 7.4
<#
.SYNOPSIS
  Inventory repeated command shapes without modifying tasks.
.PARAMETER TaskPath
  Task root to inspect. Dynamic arguments remain distinct; no provider dependency is inferred.
.PARAMETER MinimumCount
  Minimum number of distinct tasks sharing a command shape.
.PARAMETER InstallerTracking
  List scripts with validator/hash state or unified tracking calls for migration
  review. This is an inventory of syntax, not proof that a source is versionless.
.OUTPUTS
  Objects containing command names, parameter names, line numbers and task names.
  Argument values, URLs, tokens and request bodies are never included.
#>
param ([string]$TaskPath = (Join-Path $PSScriptRoot '..' '..' 'Tasks'), [ValidateRange(2, 10000)][int]$MinimumCount = 3, [switch]$InstallerTracking)
$Groups = [Collections.Generic.Dictionary[string, Collections.Generic.List[object]]]::new([StringComparer]::Ordinal)
foreach ($File in Get-ChildItem -LiteralPath $TaskPath -Filter Script.ps1 -Recurse -File) {
  $Errors = $null
  $Ast = [Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref]$null, [ref]$Errors)
  if ($Errors.Count) { Write-Warning "Skipping invalid script: $($File.Directory.Name)"; continue }
  if ($InstallerTracking) {
    $Signals = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $Migrated = $false
    foreach ($Node in $Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.MemberExpressionAst] -or $Node -is [Management.Automation.Language.IndexExpressionAst] }, $true)) {
      $Member = if ($Node -is [Management.Automation.Language.MemberExpressionAst]) { $Node.Member } else { $Node.Index }
      if ($Member -isnot [Management.Automation.Language.StringConstantExpressionAst]) { continue }
      if ($Member.Value -eq 'CheckInstallerUpdates') { $Migrated = $true }
      $Container = if ($Node -is [Management.Automation.Language.MemberExpressionAst]) { $Node.Expression } else { $Node.Target }
      $IsState = $Container -is [Management.Automation.Language.MemberExpressionAst] -and $Container.Member -is [Management.Automation.Language.StringConstantExpressionAst] -and $Container.Member.Value -in 'LastState', 'CurrentState'
      if ($IsState -and $Member.Value -match '^(ETag|LastModified|Last-Modified|ContentLength|Content-Length|Hash)(X64|X86|Arm64)?$') { $null = $Signals.Add($Member.Value) }
    }
    if ($Migrated -or $Signals.Count) {
      [pscustomobject]@{ Task = $File.Directory.Name; Migrated = $Migrated; Signals = @($Signals | Sort-Object); Review = if ($File.Directory.Name -eq 'Amazon.EC2Launch') { 'Deferred: versioned URL transition' } elseif ($Migrated) { 'Unified workflow' } else { 'Review source and legacy state before migration' } }
    }
    continue
  }
  foreach ($Command in $Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.CommandAst] }, $true)) {
    $Name = $Command.GetCommandName()
    if ($Name -notmatch '^(Invoke-|Get-|ConvertFrom-|Read-|Expand-|Use-)') { continue }
    $Parameters = @($Command.CommandElements | Where-Object { $_ -is [Management.Automation.Language.CommandParameterAst] } | ForEach-Object ParameterName)
    $Key = "$Name|$($Parameters -join ',')"
    if (-not $Groups.ContainsKey($Key)) { $Groups[$Key] = [Collections.Generic.List[object]]::new() }
    $Groups[$Key].Add([pscustomobject]@{ Task = $File.Directory.Name; Line = $Command.Extent.StartLineNumber })
  }
}
foreach ($Key in $Groups.Keys | Sort-Object) {
  $Tasks = @($Groups[$Key].Task | Sort-Object -Unique)
  if ($Tasks.Count -ge $MinimumCount) {
    [pscustomobject]@{ CommandShape = $Key; TaskCount = $Tasks.Count; Locations = $Groups[$Key].ToArray() }
  }
}
