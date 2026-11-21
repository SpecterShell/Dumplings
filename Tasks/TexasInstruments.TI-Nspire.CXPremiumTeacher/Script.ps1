$Prefix = 'https://education.ti.com/en/software/details/en/B993F3BD97D94D7EA35E5D514DD57FB5/ti-nspirecx-tps_sda'
$Object1 = Invoke-WebRequest -Uri $Prefix

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.msi') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # Documentations (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'Documentations'
        Value  = @(
          @{
            DocumentLabel = 'Guidebook'
            DocumentUrl   = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('Guidebook') -and $_.href.Contains('EN') } catch {} }, 'First')[0].href
          }
        )
      }
      # Documentations (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = '指导手册'
            DocumentUrl   = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('Guidebook') -and $_.href.Contains('ZH_CN') } catch {} }, 'First')[0].href
          }
        )
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
