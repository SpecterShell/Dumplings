$LocalStorage.WondershareUpgradeInfo = [ordered]@{}

@('x64', 'x86').ForEach(
  {
    $Arch = $_
    Invoke-RestMethod -Uri 'https://pc-api.300624.com/v2/product/batch-check-upgrade' -Method Post -Body (@{
        platform = "win_${Arch}"
        versions = $Task.Config.Products.GetEnumerator().Where({ $_.Value.x86 -eq ($Arch -eq 'x86') }).ForEach({ @{ pid = $_.Key; version = $_.Value.Version } })
      } | ConvertTo-Json -Compress)
  }
).data.ForEach(
  {
    $LocalStorage.WondershareUpgradeInfo[$_.pid.ToString()] = [ordered]@{
      # Version
      Version   = $_.version
      # Installer
      Installer = @(
        [ordered]@{
          InstallerUrl = $_.full.url.Replace('upgrade', 'cbs_down') | ConvertTo-Https
        }
      )
      # ReleaseNotes
      Locale    = @(
        [ordered]@{
          Locale = $Task.Config.Products[$_.pid.ToString()].Locale
          Key    = 'ReleaseNotes'
          Value  = $_.whats_new_content | Format-Text
        }
      )
    }
  }
)
