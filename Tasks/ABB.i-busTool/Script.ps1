# $Object1 = Invoke-WebRequest -Uri 'http://www.knx-gebaeudesysteme.de/sto_g/i-bus-tool/_NEW2_/ABB/UpdateDescription.xml' | Read-ResponseContent | ConvertFrom-Xml

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = Get-RedirectedUrls -Uri 'https://search.abb.com/library/Download.aspx?DocumentID=9AKK106354A1779&Action=Launch' -Method GET | Select-Object -Last 1 | Split-Uri -LeftPart Path | ConvertTo-UnescapedUri
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+){2,})').Groups[1].Value

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
