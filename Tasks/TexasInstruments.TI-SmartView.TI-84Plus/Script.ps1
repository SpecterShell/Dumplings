$Prefix = 'https://education.ti.com/en/software/details/en/F6A4DD4C150B4F63BE370EBFA15BCFEF/ti-smartview-ce-for-ti-84-plus-family-v6_0_3'
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
            DocumentUrl   = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('EN') } catch {} }, 'First')[0].href
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
            DocumentUrl   = Join-Uri $Prefix $Object1.Links.Where({ try { $_.href.EndsWith('.pdf') -and $_.href.Contains('ZH') } catch {} }, 'First')[0].href
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
