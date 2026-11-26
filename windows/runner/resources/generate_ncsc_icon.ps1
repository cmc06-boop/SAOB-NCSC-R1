param(
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Destination
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$original = [System.Drawing.Image]::FromFile($Source)
$frames = @()
try {
    foreach ($size in @(16, 24, 32, 48, 64, 128, 256)) {
        $bitmap = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $stream = New-Object System.IO.MemoryStream
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $ratio = [Math]::Min($size / $original.Width, $size / $original.Height)
            $w = [Math]::Max(1, [int][Math]::Round($original.Width * $ratio))
            $h = [Math]::Max(1, [int][Math]::Round($original.Height * $ratio))
            $left = [int][Math]::Floor(($size - $w) / 2)
            $top = [int][Math]::Floor(($size - $h) / 2)
            $graphics.DrawImage($original, $left, $top, $w, $h)
            $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
            $frames += @{ Size = $size; Bytes = $stream.ToArray() }
        } finally {
            $stream.Dispose()
            $graphics.Dispose()
            $bitmap.Dispose()
        }
    }
} finally {
    $original.Dispose()
}
$buffer = New-Object System.IO.MemoryStream
$writer = New-Object System.IO.BinaryWriter($buffer)
try {
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$frames.Count)
    $offset = 6 + 16 * $frames.Count
    foreach ($frame in $frames) {
        $dimension = [byte]($frame.Size % 256)
        $writer.Write($dimension)
        $writer.Write($dimension)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$frame.Bytes.Length)
        $writer.Write([uint32]$offset)
        $offset += $frame.Bytes.Length
    }
    foreach ($frame in $frames) {
        $writer.Write([byte[]]$frame.Bytes)
    }
    $writer.Flush()
    [System.IO.File]::WriteAllBytes($Destination, $buffer.ToArray())
} finally {
    $writer.Dispose()
    $buffer.Dispose()
}
