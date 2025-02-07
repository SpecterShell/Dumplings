$Prefix = 'https://dl.ifile.space/update/'

$this.CurrentState = Invoke-RestMethod -Uri "${Prefix}latest.yml?noCache=$(Get-Random)" | ConvertFrom-Yaml | ConvertFrom-ElectronUpdater -Prefix $Prefix -Locale 'zh-CN'

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
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
