$Object1 = (Invoke-WebRequest -Uri 'https://gwc.eset.com/v1/product/4').Content | ConvertFrom-Json -AsHashtable
# x86
$Object2 = $Object1.files.installer.Values.Where({ $_.installer_type -eq 11 -and $_.av_remover -eq 'No' -and $_.os_group -eq '2625868' }, 'First')[0]
# x64
$Object3 = $Object1.files.installer.Values.Where({ $_.installer_type -eq 11 -and $_.av_remover -eq 'No' -and $_.os_group -eq '2625861' }, 'First')[0]
# arm64
$Object4 = $Object1.files.installer.Values.Where({ $_.installer_type -eq 11 -and $_.av_remover -eq 'No' -and $_.os_group -eq '2625864' }, 'First')[0]

if (@(@($Object2, $Object3, $Object4) | Sort-Object -Property { $_.full_version } -Unique).Count -gt 1) {
  $this.Log("Inconsistent versions: x86: $($Object2.full_version), x64: $($Object3.full_version), arm64: $($Object4.full_version)", 'Error')
  return
}

# Version
$this.CurrentState.Version = $Object3.full_version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = $Object2.url.Replace('/latest/', "/v$($this.CurrentState.Version.Split('.')[0])/$($this.CurrentState.Version)/")
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = $Object3.url.Replace('/latest/', "/v$($this.CurrentState.Version.Split('.')[0])/$($this.CurrentState.Version)/")
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = $Object4.url.Replace('/latest/', "/v$($this.CurrentState.Version.Split('.')[0])/$($this.CurrentState.Version)/")
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    try {
      # PrivacyUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'PrivacyUrl'
        Value  = "https://help.eset.com/eav/$($this.CurrentState.Version.Split('.')[0])/en-US/privacy_policy.html"
      }
      # LicenseUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'LicenseUrl'
        Value  = "https://help.eset.com/eav/$($this.CurrentState.Version.Split('.')[0])/en-US/eula.html"
      }
      # CopyrightUrl (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'CopyrightUrl'
        Value  = "https://help.eset.com/eav/$($this.CurrentState.Version.Split('.')[0])/en-US/eula.html"
      }
      # Agreements (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'Agreements'
        Value  = @(
          [ordered]@{
            AgreementLabel = 'End User License Agreement'
            AgreementUrl   = "https://help.eset.com/eav/$($this.CurrentState.Version.Split('.')[0])/en-US/eula.html"
          }
        )
      }
      # Documentations (en-US)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'en-US'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = 'Documentation'
            DocumentUrl   = "https://help.eset.com/eav/$($this.CurrentState.Version.Split('.')[0])/en-US/"
          }
        )
      }
      # PrivacyUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'PrivacyUrl'
        Value  = "https://help.eset.com/eav/$($this.CurrentState.Version.Split('.')[0])/zh-CN/privacy_policy.html"
      }
      # LicenseUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'LicenseUrl'
        Value  = "https://help.eset.com/eav/$($this.CurrentState.Version.Split('.')[0])/zh-CN/eula.html"
      }
      # CopyrightUrl (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'CopyrightUrl'
        Value  = "https://help.eset.com/eav/$($this.CurrentState.Version.Split('.')[0])/zh-CN/eula.html"
      }
      # Agreements (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Agreements'
        Value  = @(
          [ordered]@{
            AgreementLabel = '最终用户许可协议 (EULA)'
            AgreementUrl   = "https://help.eset.com/eav/$($this.CurrentState.Version.Split('.')[0])/zh-CN/eula.html"
          }
        )
      }
      # Documentations (zh-CN)
      $this.CurrentState.Locale += [ordered]@{
        Locale = 'zh-CN'
        Key    = 'Documentations'
        Value  = @(
          [ordered]@{
            DocumentLabel = 'Documentation'
            DocumentUrl   = "https://help.eset.com/eav/$($this.CurrentState.Version.Split('.')[0])/zh-CN/"
          }
        )
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    try {
      $ReleaseNotesObject = $Object1.changelogs.Where({ $_.product_id -eq 4 }, 'First')[0].changelogs.'en_US' | ConvertFrom-Html
      $ReleaseNotesTitleNode = $ReleaseNotesObject.SelectSingleNode("//h3[contains(text(), '$($this.CurrentState.Version)')]")
      if ($ReleaseNotesTitleNode) {
        $ReleaseNotesNodes = for ($Node = $ReleaseNotesTitleNode.NextSibling; $Node -and $Node.Name -ne 'h3'; $Node = $Node.NextSibling) { $Node }
        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $ReleaseNotesNodes | Get-TextContent | Format-Text
        }
      } else {
        $this.Log("No ReleaseNotes (en-US) for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    foreach ($Installer in $this.CurrentState.Installer) {
      $this.InstallerFiles[$Installer.InstallerUrl] = $InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl
      $InstallerFileExtracted = New-TempFolder
      7z.exe e -aoa -ba -bd '-t#' -o"${InstallerFileExtracted}" $InstallerFile '*.msi' | Out-Host
      $InstallerFile2 = Join-Path $InstallerFileExtracted '*.msi' | Get-Item -Force | Select-Object -First 1
      # ProductCode
      $Installer['ProductCode'] = $InstallerFile2 | Read-ProductCodeFromMsi
      Remove-Item -Path $InstallerFileExtracted -Recurse -Force -ErrorAction 'Continue' -ProgressAction 'SilentlyContinue'
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
