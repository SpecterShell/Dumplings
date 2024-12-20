$Object1 = Invoke-WebRequest -Uri 'https://www.iqiyi.com/appstore.html' | ConvertFrom-Html
$Object2 = $Object1.SelectSingleNode('//li[contains(@class, "app-item") and contains(.//h3[@class="main-title"], "爱奇艺万能播放")]')

# Version
$this.CurrentState.Version = [regex]::Match($Object2.SelectSingleNode('.//p[@class="sub-ver"]').InnerText, '(\d+\.\d+\.\d+\.\d+)').Groups[1].Value

# Installer
$this.CurrentState.Installer += [ordered]@{
  InstallerUrl = $Object2.SelectSingleNode('.//a[@class="mod-btn"]').Attributes['href'].Value
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
