$InstallerLink = $Global:DumplingsStorage.BrinkSoftwareDownloadPage.Links.Where({ try { $_.OuterHTML.Contains('Ibis voor Infra') -and $_.OuterHTML.Contains('setup') } catch {} }, 'First')[0]

# Version
$this.CurrentState.Version = [regex]::Match($InstallerLink.OuterHtml, '(\d+(?:\.\d+){2,})').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $InstallerLink.href | ConvertTo-UnescapedUri
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
    $this.Submit()
  }
}
