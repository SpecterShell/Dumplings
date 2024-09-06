# Global
$this.CurrentState.Installer += $Installer = [ordered]@{
  InstallerUrl = 'https://download.updf.com/updf/basic/win/updf-9000000000-win-full.exe'
}
$Object1 = Invoke-WebRequest -Uri $Installer.InstallerUrl -Method Head
$this.CurrentState.ETag = $Object1.Headers.ETag[0]
if (-not $Global:DumplingsPreference.Contains('Force') -and -not $this.Status.Contains('New') -and $this.CurrentState.ETag -eq $this.LastState.ETag) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

# China
$this.CurrentState.Installer += $InstallerCN = [ordered]@{
  InstallerLocale = 'zh-CN'
  InstallerUrl    = 'https://download.updf.cn/updf/basic/win/updf-8000000000-win-full.exe'
}
$Object2 = Invoke-WebRequest -Uri $InstallerCN.InstallerUrl -Method Head
$this.CurrentState.ETagCN = $Object2.Headers.ETag[0]
if (-not $Global:DumplingsPreference.Contains('Force') -and -not $this.Status.Contains('New') -and $this.CurrentState.ETagCN -eq $this.LastState.ETagCN) {
  $this.Log("The version $($this.LastState.Version) from the last state is the latest, skip checking", 'Info')
  return
}

$InstallerFile = Get-TempFile -Uri $Installer.InstallerUrl

# InstallerSha256
$Installer['InstallerSha256'] = (Get-FileHash -Path $InstallerFile -Algorithm SHA256).Hash

# Version
$InstallerFileExtracted = New-TempFolder
7z.exe e -aoa -ba -bd -y -o"${InstallerFileExtracted}" $InstallerFile 'UPDF.exe' | Out-Host
$this.CurrentState.Version = Join-Path $InstallerFileExtracted 'UPDF.exe' | Read-ProductVersionFromExe

switch -Regex ($this.Check()) {
  'New|Changed|Updated|Rollbacked' {
    try {
      if ($Global:DumplingsStorage.Contains('UPDF') -and $Global:DumplingsStorage.UPDF.Contains($this.CurrentState.Version)) {

        # ReleaseNotes (en-US)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'en-US'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.UPDF[$this.CurrentState.Version].ReleaseNotesEN
        }
        # ReleaseNotes (zh-CN)
        $this.CurrentState.Locale += [ordered]@{
          Locale = 'zh-CN'
          Key    = 'ReleaseNotes'
          Value  = $Global:DumplingsStorage.UPDF[$this.CurrentState.Version].ReleaseNotesCN
        }
      } else {
        $this.Log("No ReleaseNotes for version $($this.CurrentState.Version)", 'Warning')
      }
    } catch {
      $_ | Out-Host
      $this.Log($_, 'Warning')
    }

    $this.Print()
    $this.Write()
  }
  'Changed|Updated|Rollbacked' {
    $this.Message()
  }
  'Updated|Rollbacked' {
    $this.Submit()
  }
}
