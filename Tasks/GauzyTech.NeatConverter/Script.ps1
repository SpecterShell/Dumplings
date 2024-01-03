$Object1 = Invoke-WebRequest -Uri 'https://www.neat-reader.cn/downloads/converter' | ConvertFrom-Html

# Version
$this.CurrentState.Version = [regex]::Match(
  $Object1.SelectSingleNode('/html/body/div[2]/section[1]/section/div/p[2]').InnerText,
  '([\d\.]+)'
).Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object1.SelectSingleNode('/html/body/div[2]/section[1]/section/div/a').Attributes['href'].Value | ConvertTo-UnescapedUri
}

switch ($this.Check()) {
  ({ $_ -ge 1 }) {
    $this.Write()
  }
  ({ $_ -ge 2 }) {
    $this.Message()
  }
  ({ $_ -ge 3 }) {
    $this.Submit()
  }
}
