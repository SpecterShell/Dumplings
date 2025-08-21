$Prefix = 'https://download.blender.org/release/'

$Object1 = Invoke-WebRequest -Uri $Prefix

$Prefix += $Object1.Links | Where-Object -FilterScript { try { $_.href -match 'Blender\d+(?:\.\d+)+/' } catch {} } | Select-Object -ExpandProperty 'href' | Sort-Object -Property { [version][regex]::Match($_, '(\d+(?:\.\d+)+)').Groups[1].Value } -Bottom 1

$Object2 = Invoke-WebRequest -Uri $Prefix

$InstallerName = $Object2.Links | Where-Object -FilterScript { try { $_.href.EndsWith('.msi') -and $_.href.Contains('x64') } catch {} } | Select-Object -ExpandProperty 'href' | Sort-Object -Property { [version][regex]::Match($_, '(\d+(?:\.\d+)+)').Groups[1].Value } -Bottom 1

# Version
$this.CurrentState.Version = [regex]::Match($InstallerName, '(\d+(?:\.\d+)+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Join-Uri $Prefix $InstallerName
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    # try {
    #   # ReleaseNotesUrl
    #   $this.CurrentState.Locale += [ordered]@{
    #     Key   = 'ReleaseNotesUrl'
    #     Value = "https://www.blender.org/download/releases/$($this.CurrentState.Version.Split('.')[0..1] -join '-')/"
    #   }
    # } catch {
    #   $_ | Out-Host
    #   $this.Log($_, 'Warning')
    # }

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
