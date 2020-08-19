use v6;
use Test;
plan 1;

use Cairo;
use HTML::Canvas;
use HTML::Canvas::To::Cairo;
use HTML::Canvas::Path2D;

my HTML::Canvas $canvas .= new;
my $feed = HTML::Canvas::To::Cairo.new: :width(612), :height(792), :$canvas;

# adapted from https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/fill

$canvas.context: -> \ctx {
    # Create path
    my HTML::Canvas::Path2D \region .= new;
    region.moveTo(30, 90);
    region.lineTo(110, 20);
    region.lineTo(240, 130);
    region.lineTo(60, 130);
    region.lineTo(190, 20);
    region.lineTo(270, 90);
    region.closePath();

    ctx.fillStyle = 'green';
    ctx.fill(region, 'evenodd');

    ctx.translate(100, 100);
    ctx.fillStyle = 'blue';
    ctx.fill(region);
}

# save canvas as as PNG
my Cairo::Surface $surface = $feed.surface;
$surface.write_png: "tmp/path2d.png";

pass();
my $html = "<html><body>{ $canvas.to-html( :width(612), :height(792) ) }</body></html>";
"t/path-2d.html".IO.spurt: $html;

done-testing();
