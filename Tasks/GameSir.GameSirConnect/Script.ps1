$Object1 = curl -fsSL --resolve "www.xiaoji.com:443:$(Resolve-DnsName -Name 'www.xiaoji.com' -Server '114.114.114.114' -Type 'A' -DnsOnly | Where-Object -FilterScript { $_ -is [Microsoft.DnsClient.Commands.DnsRecord_A] } | Select-Object -ExpandProperty 'IP4Address' -First 1)" 'https://www.xiaoji.com/page/version_list' | Join-String -Separator "`n" | Get-EmbeddedLinks

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.Where({ try { $_.href.EndsWith('.exe') -and $_.href.Contains('GameSir-Connect') } catch {} }, 'First')[0].href
}

# Version
$this.CurrentState.Version = [regex]::Match($this.CurrentState.Installer[0].InstallerUrl, '(\d+(?:\.\d+)+)').Groups[1].Value

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
