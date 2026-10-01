# Drupal Views AJAX of the downloads page, pre-filtered to Windows rows; the
# filtered result set is contiguous, so the first page without rows ends it.
$Builds = for ($Page = 0; $Page -lt 40; $Page++) {
  $Build = (Invoke-RestMethod -Uri "https://www.openlogic.com/views/ajax?field_operating_system_target_id=202&field_architecture_target_id=All&field_java_package_target_id=All&view_name=openjdk_downloads&view_display_id=openjdk_downloads&view_args=&view_path=/node/1098&pager_element=0&page=$Page") |
    Where-Object -FilterScript { $_.command -eq 'insert' } | Select-Object -ExpandProperty 'data' |
    Join-String -Separator '' | Get-EmbeddedLinks | ForEach-Object -Process {
      if ($_.href -match '(?<package>openlogic-openjdk(?:-jre)?)/(?<version>[^/]+)/(?:openlogic-[^/"]+-windows-(?:x64|x32)\.msi)') {
        [pscustomobject]@{
          Package = $Matches['package']
          Version = $Version = $Matches['version']
          Arch    = $_.href.Contains('windows-x64') ? 'x64' : 'x86'
          Url     = $_.href
          SortKey = $Version -match '^8u(\d+)-b(\d+)$' ? [version]"8.$($Matches[1]).$($Matches[2])" : [version]($Version -replace '\+', '.')
        }
      }
    }
  if ($null -eq $Build) { break }
  $Build
}

$Global:DumplingsStorage.OpenLogicBuilds = @($Builds | Sort-Object -Property Url -Unique | Sort-Object -Property SortKey -Descending)
