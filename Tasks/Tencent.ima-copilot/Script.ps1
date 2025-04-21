$Object1 = Invoke-RestMethod -Uri 'https://oi.rb.qq.com/config.v2.ConfigService/PullConfigReq' -Method Post -Headers @{
  rainbow_sdk_version = 'browser_sdk_v0.0.1'
  rainbow_sgn_method  = $RainbowSgnMethod = 'sha1'
  rainbow_nonce       = $RainbowNonce = '0'
  rainbow_timestamp   = $RainbowTimestamp = [System.DateTimeOffset]::Now.ToUnixTimeSeconds().ToString()
  rainbow_user_id     = $RainbowUserID = '4b9f63a542b14454a44d25632ef78053'
  rainbow_app_id      = $RainbowAppID = 'e6ee3c8c-4eae-4f0a-b164-458befd8cdab'
  rainbow_version     = $RainbowVersion = '2020'
  rainbow_signature   = [System.Convert]::ToBase64String(
    [System.Security.Cryptography.HMACSHA1]::HashData(
      [System.Text.Encoding]::UTF8.GetBytes($Global:DumplingsSecret.IMAKey),
      [System.Text.Encoding]::UTF8.GetBytes(($Global:DumplingsSecret.IMASource -f $RainbowSgnMethod, $RainbowNonce, $RainbowTimestamp, $RainbowUserID, $RainbowAppID, $RainbowVersion))
    )
  )
} -Body (
  @{
    client_infos = @(@{ client_identified_name = 'ip'; client_identified_value = '127.0.0.1' })
    pull_item    = @{ app_id = $RainbowAppID; group = 'ima-download-config'; key = 'download-config' }
  } | ConvertTo-Json -Compress -Depth 5
) -ContentType 'application/json'
$Object2 = $Object1.config.items[0].key_values[0].value | ConvertFrom-Json

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.official.win.url
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+\.\d+\.\d+_\d+)').Groups[1].Value.Replace('_', '.')

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.InstallerFiles[$this.CurrentState.Installer[0].InstallerUrl] = $InstallerFile = Get-TempFile -Uri $this.CurrentState.Installer[0].InstallerUrl
    $InstallerFileExtracted = New-TempFolder
    7z.exe e -aoa -ba -bd -y '-t#' -o"${InstallerFileExtracted}" $InstallerFile '2.exe' | Out-Host
    $InstallerFile2 = Join-Path $InstallerFileExtracted '2.exe'
    # RealVersion
    $this.CurrentState.RealVersion = $InstallerFile2 | Read-ProductVersionFromExe
    Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'

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
