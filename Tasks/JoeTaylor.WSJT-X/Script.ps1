$ProjectName = 'wsjt'
$RootPath = ''
$PatternPath = 'wsjtx-(\d+(?:\.\d+)+)'
$PatternFilename = 'wsjtx-.+\.exe'

$Object1 = Invoke-RestMethod -Uri "https://sourceforge.net/projects/${ProjectName}/rss?path=${RootPath}"
$Assets = $Object1.Where({ $_.title.'#cdata-section' -match "^$([regex]::Escape($RootPath))/${PatternPath}/${PatternFilename}$" })

# Installer
$Asset = $Assets.Where({ $_.title.'#cdata-section'.Contains('win32') }, 'First')[0]
$VersionX86 = [regex]::Match($Asset.title.'#cdata-section', "^$([regex]::Escape($RootPath))/${PatternPath}/").Groups[1].Value
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Asset.link | ConvertTo-UnescapedUri
  ProductCode  = "wsjtx ${VersionX86}"
}

$Asset = $Assets.Where({ $_.title.'#cdata-section'.Contains('win64') }, 'First')[0]
$VersionX64 = [regex]::Match($Asset.title.'#cdata-section', "^$([regex]::Escape($RootPath))/${PatternPath}/").Groups[1].Value
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Asset.link | ConvertTo-UnescapedUri
  ProductCode  = "wsjtx ${VersionX64}"
}

if ($VersionX86 -ne $VersionX64) {
  $this.Log("x86 version: ${VersionX86}")
  $this.Log("x64 version: ${VersionX64}")
  throw 'Inconsistent versions detected'
}

# Version
$this.CurrentState.Version = $VersionX64

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # ReleaseTime
      $this.CurrentState.ReleaseTime = [datetime]::ParseExact(
        $Assets.Where({ $_.title.'#cdata-section'.EndsWith('.exe') -and $_.title.'#cdata-section'.Contains('win64') }, 'First')[0].pubDate,
        'ddd, dd MMM yyyy HH:mm:ss "UT"',
        (Get-Culture -Name 'en-US')
      ) | ConvertTo-UtcDateTime -Id 'UTC'

      # Documentations
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'Documentations'
        Value = @(
          [ordered]@{
            DocumentLabel = 'User Guide'
            DocumentUrl   = "https://wsjt.sourceforge.io/wsjtx-doc/wsjtx-main-$($this.CurrentState.Version).html"
          }
          [ordered]@{
            DocumentLabel = 'Q65 Mode Quick-Start Guide'
            DocumentUrl   = 'https://wsjt.sourceforge.io/Q65_Quick_Start.pdf'
          }
          [ordered]@{
            DocumentLabel = 'SuperFox Mode User Guide'
            DocumentUrl   = 'https://wsjt.sourceforge.io/SuperFox_User_Guide.pdf'
          }
          [ordered]@{
            DocumentLabel = 'WSJT-X and MAP65 Quick-Start Guide'
            DocumentUrl   = 'https://wsjt.sourceforge.io/WSJTX_2.5.0_MAP65_3.0_Quick_Start.pdf'
          }
          [ordered]@{
            DocumentLabel = 'FT8 DXpedition Mode User Guide'
            DocumentUrl   = 'https://wsjt.sourceforge.io/FT8_DXpedition_Mode.pdf'
          }
        )
      }
      # Documentations (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = '用户指南'
            DocumentUrl   = "https://wsjt.sourceforge.io/wsjtx-doc/wsjtx-main-$($this.CurrentState.Version).html"
          }
          [ordered]@{
            DocumentLabel = 'Q65 模式 快速入门'
            DocumentUrl   = 'https://wsjt.sourceforge.io/Q65_Quick_Start.pdf'
          }
          [ordered]@{
            DocumentLabel = 'SuperFox 模式 使用指南'
            DocumentUrl   = 'https://wsjt.sourceforge.io/SuperFox_User_Guide.pdf'
          }
          [ordered]@{
            DocumentLabel = 'WSJT-X 和 MAP65 快速入门'
            DocumentUrl   = 'https://wsjt.sourceforge.io/WSJTX_2.5.0_MAP65_3.0_Quick_Start.pdf'
          }
          [ordered]@{
            DocumentLabel = 'FT8 远征模式 使用指南'
            DocumentUrl   = 'https://wsjt.sourceforge.io/FT8_DXpedition_Mode_Chinese.pdf'
          }
        )
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      # ReleaseNotesUrl
      $this.CurrentState.Locale += [ordered]@{
        Key   = 'ReleaseNotesUrl'
        Value = $ReleaseNotesUrl = "https://wsjt.sourceforge.io/wsjtx-doc/Release_Notes_$($this.CurrentState.Version).txt"
      }

      try {
        $Object2 = [System.IO.StreamReader]::new((Invoke-WebRequest -Uri $ReleaseNotesUrl).RawContentStream)

        while (-not $Object2.EndOfStream) {
          if ($Object2.ReadLine() -match "Release: WSJT-X $([regex]::Escape($this.CurrentState.Version))") {
            1..3 | ForEach-Object { $null = $Object2.ReadLine() }
            break
          }
        }
        if (-not $Object2.EndOfStream) {
          $ReleaseNotesObjects = [System.Collections.Generic.List[string]]::new()
          while (-not $Object2.EndOfStream) {
            $String = $Object2.ReadLine()
            if ($String -notmatch 'Release: WSJT-X \d+(?:\.\d+)+') {
              $ReleaseNotesObjects.Add($String)
            } else {
              break
            }
          }
          # ReleaseNotes (en-US)
          $this.CurrentState.Locale += [ordered]@{
            Locale = 'en-US'
            Key    = 'ReleaseNotes'
            Value  = $ReleaseNotesObjects | Format-Text
          }
        } else {
          $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
        }
      } catch {
        $_ | Out-Host
        $this.Log($_, 'Warning')
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
