$Object1 = Invoke-RestMethod -Uri 'https://msedge.api.cdp.microsoft.com/api/v2/contents/Browser/namespaces/Default/names?action=batchupdates' -Method Post -Body (
  @(
    [ordered]@{
      Product             = 'msedgewebview-stable-win-x86'
      targetingAttributes = [ordered]@{
        AppRollout = 0
      }
    },
    [ordered]@{
      Product             = 'msedgewebview-stable-win-x64'
      targetingAttributes = [ordered]@{
        AppRollout = 0
      }
    },
    [ordered]@{
      Product             = 'msedgewebview-stable-win-arm64'
      targetingAttributes = [ordered]@{
        AppRollout = 0
      }
    }
  ) | ConvertTo-Json -Compress -AsArray
) -ContentType 'application/json'

if (@($Object1.ContentId.Version | Sort-Object -Unique).Count -gt 1) {
  $this.Log("x86 version: $($Object1[0].ContentId.Version)")
  $this.Log("x64 version: $($Object1[1].ContentId.Version)")
  $this.Log("arm64 version: $($Object1[2].ContentId.Version)")
  throw 'Distinct versions detected'
}

# Version
$this.CurrentState.Version = $Object1[1].ContentId.Version

# Installer
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x86'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2099617'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'x64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2124701'
}
$this.CurrentState.Installer += [ordered]@{
  Architecture = 'arm64'
  InstallerUrl = Get-RedirectedUrl -Uri 'https://go.microsoft.com/fwlink/?linkid=2099616'
}

switch -Regex ($this.Check()) {
  'New|Changed|Updated' {
    $this.Print()
    $this.Write()
  }
  'Changed|Updated' {
    $this.Message()
  }
  'Updated' {
    if (Compare-Object -ReferenceObject $this.LastState.Installer.InstallerUrl -DifferenceObject $this.CurrentState.Installer.InstallerUrl -IncludeEqual -ExcludeDifferent) {
      throw 'Not all installers have been updated'
    }
    $this.Submit()
  }
}
