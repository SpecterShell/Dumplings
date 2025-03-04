$Prefix = 'https://dl.ifile.space/update/'

$Object1 = Invoke-RestMethod -Uri "${Prefix}latest.yml" | ConvertFrom-Yaml

# Version
$this.CurrentState.Version = $Object1.version

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.files[0].url
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = $Object1.releaseDate | Get-Date -AsUTC
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $Object2 = Invoke-RestMethod -Uri 'https://ifile.space/update' -Method Post -Body (
        @{
          action = 'desktop'
        } | ConvertTo-Json -Compress
      ) -ContentType 'application/json; charset=utf-8'
      $Object3 = $Object2.data.list.Where({ $_.title -eq $this.CurrentState.Version }, 'First')

      if ($Object3) {
        # ReleaseTime
        $this.CurrentState.ReleaseTime ??= [datetime]::ParseExact($Object3[0].addtime.ToString(), 'yyyyMMdd', $null).ToString('yyyy-MM-dd')

        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Object3[0].contentfmt | ForEach-Object -Process {
            $TypeName = switch ($_.Type) {
              'youhua' { '优化' }
              'xiufu' { '修复' }
              'xinzeng' { '新增' }
              Default { $_ }
            }
            "【${TypeName}】$($_.content)"
          } | Format-Text
        }
      } else {
        $this.Log("No ReleaseTime and ReleaseNotes (zh-CN) for version $($this.CurrentState.Version)", 'Warning')
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
