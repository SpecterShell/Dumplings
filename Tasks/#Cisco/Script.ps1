$Global:DumplingsStorage.CiscoDownloadPage = Use-EdgeDriver {
  param($EdgeDriver)
  $EdgeDriver.Navigate().GoToUrl('https://www.webex.com/video-recording.html')
  $EdgeDriver.PageSource
} | Get-EmbeddedLinks
