# Tiny local server for the ZEN Scene Builder (no Python/Node needed).
#  - serves the app's static files
#  - stores your model library on disk in the "library" folder next to this script (GET/PUT/DELETE /api/library...)
# Usage:  powershell -ExecutionPolicy Bypass -File serve.ps1 [-Port 5173]
param([int]$Port = 5173)
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$libDir = Join-Path $root 'library'
$sceneDir = Join-Path $root 'scenes'
New-Item -ItemType Directory -Force $libDir | Out-Null
New-Item -ItemType Directory -Force $sceneDir | Out-Null
$types = @{'.html'='text/html; charset=utf-8';'.js'='text/javascript';'.css'='text/css';'.json'='application/json';'.png'='image/png';'.glb'='model/gltf-binary';'.pdf'='application/pdf';'.svg'='image/svg+xml'}
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
Write-Host "ZEN Scene Builder running at http://localhost:$Port/  (Ctrl+C to stop)"
Write-Host "Model library folder: $libDir"
Write-Host "Saved scenes folder:  $sceneDir"
function Send-Json($c, [string]$text) {
  $b = [Text.Encoding]::UTF8.GetBytes($text); $c.Response.ContentType = 'application/json'; $c.Response.OutputStream.Write($b, 0, $b.Length)
}
while ($l.IsListening) {
  $c = $l.GetContext()
  try {
    $u = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath)
    $m = $c.Request.HttpMethod
    if ($u -like '/api/library*') {
      # a custom header makes browsers pre-flight cross-site requests, which this server never answers — so only this app can write
      if ($c.Request.Headers['X-ZEN'] -ne '1') { $c.Response.StatusCode = 403 }
      elseif ($u -eq '/api/library' -and $m -eq 'GET') {
        $metaFile = Join-Path $libDir 'library.json'
        $meta = if (Test-Path $metaFile) { (Get-Content $metaFile -Raw -Encoding UTF8) } else { '[]' }
        if (-not $meta -or $meta.Trim() -eq '') { $meta = '[]' }
        $files = @(Get-ChildItem $libDir -File | Where-Object { $_.Extension -in '.glb', '.gltf' } | ForEach-Object { $_.Name })
        Send-Json $c ('{"meta":' + $meta + ',"files":' + (ConvertTo-Json -InputObject $files -Compress) + '}')
      }
      elseif ($u -eq '/api/library.json' -and $m -eq 'PUT') {
        $ms = New-Object IO.MemoryStream; $c.Request.InputStream.CopyTo($ms)
        [IO.File]::WriteAllBytes((Join-Path $libDir 'library.json'), $ms.ToArray()); $c.Response.StatusCode = 204
      }
      elseif ($u -like '/api/library/*' -and ($m -eq 'PUT' -or $m -eq 'DELETE')) {
        $name = $u.Substring('/api/library/'.Length)
        if ($name -notmatch '^[\w.\- ]+\.(glb|gltf)$' -or $name.Contains('..')) { $c.Response.StatusCode = 400 }
        else {
          $path = Join-Path $libDir $name
          if ($m -eq 'PUT') { $ms = New-Object IO.MemoryStream; $c.Request.InputStream.CopyTo($ms); [IO.File]::WriteAllBytes($path, $ms.ToArray()) }
          elseif (Test-Path $path) { Remove-Item $path -Force }
          $c.Response.StatusCode = 204
        }
      }
      else { $c.Response.StatusCode = 404 }
    } elseif ($u -like '/api/scenes*') {
      # saved scenes live as small .zenscene.json files in the "scenes" folder
      if ($c.Request.Headers['X-ZEN'] -ne '1') { $c.Response.StatusCode = 403 }
      elseif ($u -eq '/api/scenes' -and $m -eq 'GET') {
        $list = @(Get-ChildItem $sceneDir -File -Filter '*.json' | ForEach-Object { @{ file = $_.Name; updated = [long]([DateTimeOffset]$_.LastWriteTimeUtc).ToUnixTimeMilliseconds() } })
        Send-Json $c (ConvertTo-Json -InputObject $list -Compress)
      }
      elseif ($u -like '/api/scenes/*') {
        $name = $u.Substring('/api/scenes/'.Length)
        if ($name -notmatch '^[\w.\- ]+\.json$' -or $name.Contains('..')) { $c.Response.StatusCode = 400 }
        else {
          $path = Join-Path $sceneDir $name
          if ($m -eq 'GET') { if (Test-Path $path) { Send-Json $c (Get-Content $path -Raw -Encoding UTF8) } else { $c.Response.StatusCode = 404 } }
          elseif ($m -eq 'PUT') { $ms = New-Object IO.MemoryStream; $c.Request.InputStream.CopyTo($ms); [IO.File]::WriteAllBytes($path, $ms.ToArray()); $c.Response.StatusCode = 204 }
          elseif ($m -eq 'DELETE') { if (Test-Path $path) { Remove-Item $path -Force }; $c.Response.StatusCode = 204 }
          else { $c.Response.StatusCode = 405 }
        }
      }
      else { $c.Response.StatusCode = 404 }
    } else {
      $p = $u.TrimStart('/'); if ($p -eq '') { $p = 'index.html' }
      $f = Join-Path $root $p
      if ((Test-Path $f -PathType Leaf) -and ((Resolve-Path $f).Path.StartsWith($root))) {
        $b = [IO.File]::ReadAllBytes($f)
        $ext = [IO.Path]::GetExtension($f).ToLower()
        $c.Response.ContentType = if ($types[$ext]) { $types[$ext] } else { 'application/octet-stream' }
        $c.Response.OutputStream.Write($b, 0, $b.Length)
      } else { $c.Response.StatusCode = 404 }
    }
  } catch { $c.Response.StatusCode = 500 }
  $c.Response.Close()
}
