# Gera os ícones do app a partir da logo 3D (icons/logo3D.jpg, 1024 x 1024). No Windows, na pasta do
# projeto:
#   powershell -ExecutionPolicy Bypass -File tools/icones.ps1
# - icon-512.png e icon-192.png: a logo inteira (o ícone do app instalado e o da aba do navegador);
# - apple-touch-icon.png: 180 x 180, para a tela de início do iPhone;
# - icon-maskable-512.png: para o Android, que recorta o ícone em círculo (ou outra forma) e só garante
#   o miolo, um círculo de 80% da largura. Ali a logo vai a 80%, com a borda esfumada em círculo, sobre
#   um fundo escuro da cor que já envolve o anel de runas: o anel cabe inteiro;
# - preview.jpg: a imagem da prévia dos links (o convite da mesa no Discord e no WhatsApp; o og:image do
#   index.html). Em JPEG, leve: o WhatsApp costuma não mostrar imagens de prévia acima de uns 300 KB.

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class Icones {
  // A imagem inteira no tamanho pedido, com o melhor redimensionamento (e sem a borda escura que ele
  // costuma deixar).
  public static Bitmap Resize(Image src, int size) {
    var bmp = new Bitmap(size, size, PixelFormat.Format24bppRgb);
    using (var g = Graphics.FromImage(bmp))
    using (var attr = new ImageAttributes()) {
      g.InterpolationMode = InterpolationMode.HighQualityBicubic;
      g.PixelOffsetMode = PixelOffsetMode.HighQuality;
      g.CompositingQuality = CompositingQuality.HighQuality;
      attr.SetWrapMode(WrapMode.TileFlipXY);
      g.DrawImage(src, new Rectangle(0, 0, size, size), 0, 0, src.Width, src.Height, GraphicsUnit.Pixel, attr);
    }
    return bmp;
  }

  // A cor média de um anel da imagem (de r0 a r1, em fração da largura, a partir do centro), sem os
  // pontos claros (os papéis dos cantos): o fundo escuro em volta das runas.
  static double[] RingColor(Bitmap img, double r0, double r1) {
    double r = 0, g = 0, b = 0; int n = 0; double c = img.Width / 2.0;
    for (int y = 0; y < img.Height; y++) for (int x = 0; x < img.Width; x++) {
      double d = Math.Sqrt((x + .5 - c) * (x + .5 - c) + (y + .5 - c) * (y + .5 - c)) / img.Width;
      if (d < r0 || d > r1) continue;
      Color p = img.GetPixel(x, y);
      if (p.R + p.G + p.B > 150) continue;
      r += p.R; g += p.G; b += p.B; n++;
    }
    return n == 0 ? new double[] { 8, 20, 14 } : new double[] { r / n, g / n, b / n };
  }

  static double Smooth(double a, double b, double x) {
    double t = Math.Max(0, Math.Min(1, (x - a) / (b - a)));
    return t * t * (3 - 2 * t);
  }

  // O ícone que o Android recorta: a logo a `scale` da largura, esfumada num círculo, sobre o fundo.
  public static Bitmap Maskable(Image src, int size, double scale) {
    var probe = Resize(src, 256);
    double[] bg = RingColor(probe, .47, .5);
    int inner = (int)Math.Round(size * scale);
    var logo = Resize(src, inner);
    var bmp = new Bitmap(size, size, PixelFormat.Format24bppRgb);
    double c = size / 2.0, edge = inner / 2.0, fadeFrom = edge * .94, corner = c * Math.Sqrt(2);
    int off = (size - inner) / 2;
    for (int y = 0; y < size; y++) for (int x = 0; x < size; x++) {
      double d = Math.Sqrt((x + .5 - c) * (x + .5 - c) + (y + .5 - c) * (y + .5 - c));
      double shade = 1 - .35 * Smooth(edge, corner, d);   // o fundo escurece para as pontas, como a logo
      double br = bg[0] * shade, bgg = bg[1] * shade, bb = bg[2] * shade;
      double a = 1 - Smooth(fadeFrom, edge, d);
      int lx = x - off, ly = y - off;
      if (a > 0 && lx >= 0 && ly >= 0 && lx < inner && ly < inner) {
        Color p = logo.GetPixel(lx, ly);
        br = p.R * a + br * (1 - a); bgg = p.G * a + bgg * (1 - a); bb = p.B * a + bb * (1 - a);
      }
      bmp.SetPixel(x, y, Color.FromArgb((int)Math.Round(br), (int)Math.Round(bgg), (int)Math.Round(bb)));
    }
    return bmp;
  }
}
'@

$icons = Join-Path (Split-Path -Parent $PSScriptRoot) 'icons'
$logo = [System.Drawing.Image]::FromFile((Join-Path $icons 'logo3D.jpg'))
try {
  $out = @{
    'icon-512.png' = [Icones]::Resize($logo, 512)
    'icon-192.png' = [Icones]::Resize($logo, 192)
    'apple-touch-icon.png' = [Icones]::Resize($logo, 180)
    'icon-maskable-512.png' = [Icones]::Maskable($logo, 512, .8)
  }
  foreach ($name in $out.Keys) {
    $out[$name].Save((Join-Path $icons $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $out[$name].Dispose()
    "{0}: {1} KB" -f $name, [math]::Round((Get-Item (Join-Path $icons $name)).Length / 1KB)
  }
  $jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
  $quality = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $quality.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]85)
  $preview = [Icones]::Resize($logo, 512)
  $preview.Save((Join-Path $icons 'preview.jpg'), $jpeg, $quality)
  $preview.Dispose()
  "preview.jpg: {0} KB" -f [math]::Round((Get-Item (Join-Path $icons 'preview.jpg')).Length / 1KB)
} finally {
  $logo.Dispose()
}
