# perl6-HTML-Canvas
```
use v6;
# Create a simple Canvas. Save as HTML and PDF

use PDF::Content::PDF;
use HTML::Canvas;
use HTML::Canvas::To::PDF;

my HTML::Canvas $canvas .= new;

# render to a PDF page
my PDF::Content::PDF $pdf .= new;
my $gfx = $pdf.add-page.gfx;
my $feed = HTML::Canvas::To::PDF.new: :$gfx, :$canvas;

$canvas.context: -> \ctx {
    ctx.save; {
        ctx.fillStyle = "orange";
        ctx.fillRect(10, 10, 50, 50);

        ctx.fillStyle = "rgba(0, 0, 200, 0.3)";
        ctx.fillRect(35, 35, 50, 50);
    }; ctx.restore;

    ctx.font = "18px Arial";
    ctx.fillText("Hello World", 40, 75);
}

# save canvas as PDF
$pdf.save-as: "t/canvas-demo.pdf";

# also save canvas as HTML
my $width = $feed.width;
my $height = $feed.height;
my $html = "<html><body>{ $canvas.html( :$width, :$height ) }</body></html>";
"t/canvas-demo.html".IO.spurt: $html;
```
