$Param = @{
  Uri         = 'https://pcmconfig.chinacloudsites.cn/api/v3/AppConfig'
  Method      = 'Post'
  Body        = (
    @{
      Configs  = @(
        @{
          Name = 'PCM:AutoUpdateOptions'
        }
      )
      Metadata = @{
        '%Channel%' = '250000'
        # Platform    = 'X64'
        # Platform    = 'ARM64'
      }
      Pattern  = '{}_{250000}'
    } | ConvertTo-Json -Compress
  )
  ContentType = 'application/json; charset=utf-8'
}
$Object1 = (Invoke-RestMethod @Param).results.Where({ $_.name -eq 'PCM:AutoUpdateOptions' }, 'First')[0]

$Content = [Convert]::FromBase64String($Object1.content)

$Aes = [System.Security.Cryptography.AesManaged]@{
  Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
  Mode    = [System.Security.Cryptography.CipherMode]::CBC
  Key     = [Convert]::FromBase64String($Global:DumplingsSecret.PCManagerKey)
  IV      = [byte[]]($Content[0..15])
}
$AesDecryptor = $Aes.CreateDecryptor()

$Object2 = [System.Text.Encoding]::UTF8.GetString($AesDecryptor.TransformFinalBlock($Content, 16, $Content.Length - 16)) | ConvertFrom-Json

$Aes.Dispose()
$AesDecryptor.Dispose()

# Version
$this.CurrentState.Version = $Object2.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.DownloadLink
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      if (-not [string]::IsNullOrWhiteSpace($Object2.UpdateInfoEx.en)) {
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = ($Object2.UpdateInfoEx.en | ConvertFrom-Json).details | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      if (-not [string]::IsNullOrWhiteSpace($Object2.UpdateInfoEx.'zh-cn')) {
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = ($Object2.UpdateInfoEx.'zh-cn' | ConvertFrom-Json).details | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

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
