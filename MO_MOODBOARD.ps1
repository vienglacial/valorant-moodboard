param([switch]$NoBrowser,[int]$Port=0)
$ErrorActionPreference='Stop'
$moodRoot=[IO.Path]::GetFullPath($PSScriptRoot)
$moodListener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$Port)
$moodListener.Start()
$moodPort=([Net.IPEndPoint]$moodListener.LocalEndpoint).Port
$moodUrl='http://127.0.0.1:'+$moodPort+'/'
if(-not $NoBrowser){Start-Process $moodUrl}
$moodLast=Get-Date
$moodStarted=Get-Date
try {
 while(((Get-Date)-$moodLast).TotalMinutes -lt 30 -and ((Get-Date)-$moodStarted).TotalHours -lt 4){
  if(-not $moodListener.Pending()){Start-Sleep -Milliseconds 100;continue}
  $moodClient=$moodListener.AcceptTcpClient()
  try {
   $moodClient.ReceiveTimeout=4000;$moodClient.SendTimeout=4000
   $moodStream=$moodClient.GetStream()
   $moodReader=[IO.StreamReader]::new($moodStream,[Text.Encoding]::ASCII,$false,1024,$true)
   $moodLine=$moodReader.ReadLine()
   if(-not $moodLine){continue}
   $moodParts=$moodLine.Split(' ')
   do {$moodHeader=$moodReader.ReadLine()}while($moodHeader)
   $moodCode='200 OK';$moodMime='text/plain; charset=utf-8'
   $moodBody=[Text.Encoding]::UTF8.GetBytes('Not found')
   if($moodParts[0] -notin @('GET','HEAD')){$moodCode='405 Method Not Allowed'}else{
    $moodRequest=[Uri]::UnescapeDataString(($moodParts[1].Split('?')[0])).TrimStart('/')
    if(-not $moodRequest){$moodRequest='index.html'}
    $moodFile=[IO.Path]::GetFullPath((Join-Path $moodRoot $moodRequest))
    if(-not $moodFile.StartsWith($moodRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){$moodCode='403 Forbidden'}
    elseif((Test-Path -LiteralPath $moodFile -PathType Leaf) -and [IO.Path]::GetExtension($moodFile) -in @('.html','.css','.js','.png','.jpg','.jpeg','.svg','.ico')){
     $moodBody=[IO.File]::ReadAllBytes($moodFile)
     $moodMime=switch([IO.Path]::GetExtension($moodFile)){'.html'{'text/html; charset=utf-8'}'.css'{'text/css; charset=utf-8'}'.js'{'text/javascript; charset=utf-8'}'.png'{'image/png'}'.jpg'{'image/jpeg'}'.jpeg'{'image/jpeg'}'.svg'{'image/svg+xml'}default{'image/x-icon'}}
    }else{$moodCode='404 Not Found'}
   }
   $moodResponse="HTTP/1.1 $moodCode`r`nContent-Type: $moodMime`r`nContent-Length: $($moodBody.Length)`r`nReferrer-Policy: strict-origin-when-cross-origin`r`nX-Content-Type-Options: nosniff`r`nConnection: close`r`n`r`n"
   $moodBytes=[Text.Encoding]::ASCII.GetBytes($moodResponse)
   $moodStream.Write($moodBytes,0,$moodBytes.Length)
   if($moodParts[0] -eq 'GET'){$moodStream.Write($moodBody,0,$moodBody.Length)}
   $moodLast=Get-Date
  }catch{}finally{$moodClient.Close()}
 }
}finally{$moodListener.Stop()}
