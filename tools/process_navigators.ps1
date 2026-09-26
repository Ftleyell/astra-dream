Add-Type -AssemblyName System.Drawing

$brainDir = 'C:\Users\Frani\.gemini\antigravity\brain\1f8d9939-8c9e-40c8-8722-3b68b1b59aff'
$map = @{
    'lyra' = 'navigator_lyra_1790395288363.jpg'
    'vespera' = 'navigator_vespera_1790395314204.jpg'
    'caelia' = 'navigator_caelia_1790395351483.jpg'
    'zephyr' = 'navigator_zephyr_1790395403767.jpg'
    'iris' = 'navigator_iris_1790395423362.jpg'
}

foreach ($k in $map.Keys) {
    $src = Join-Path $brainDir $map[$k]
    $destFull = "assets/characters/navigators/full/navigator_$k.png"
    $destPort = "assets/characters/navigators/portraits/portrait_$k.png"
    
    $img = [System.Drawing.Image]::FromFile($src)
    $img.Save($destFull, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $w = $img.Width
    $h = $img.Height
    $cropSize = [int]($w * 0.75)
    $cropX = [int](($w - $cropSize) / 2)
    $cropY = [int]($h * 0.04)
    
    $rect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropSize, $cropSize)
    $bmpCrop = New-Object System.Drawing.Bitmap($cropSize, $cropSize)
    $g = [System.Drawing.Graphics]::FromImage($bmpCrop)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0, 0, $cropSize, $cropSize)), $rect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    
    $bmpCrop.Save($destPort, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmpCrop.Dispose()
    $img.Dispose()
    Write-Host "Processed $k -> full & portrait created"
}
