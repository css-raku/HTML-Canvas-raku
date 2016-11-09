use v6;
use Test;

use PDF::Content::PDF;
use HTML::Canvas;
use HTML::Canvas::Render::PDF;
use PDF::Style::Font;

my PDF::Style::Font $font-object .= new;
my PDF::Content::PDF $pdf .= new;
my $gfx = $pdf.add-page.gfx(:!strict);
my HTML::Canvas::Render::PDF $renderer .= new: :$gfx;
is $renderer.width, 612, 'renderer default width';
is $renderer.height, 792, 'rendered default height';
my $callback = $renderer.callback;
my HTML::Canvas $canvas .= new(:$callback, :$font-object);

$canvas.context: -> \ctx {
    is-deeply [ctx.transformMatrix], [1, 0, 0, 1, 0, 0], 'canvas transform - initial';
    is-deeply [$gfx.CTM.list], [1, 0, 0, 1, 0, 792], 'pdf transform - initial';
    ctx.strokeRect(1, 1, 610, 790);

    lives-ok { ctx.strokeRect(20,20, 10,20); }, "basic API call - lives";
    ctx.scale( 2.0, 2.0);
    is-deeply [ctx.transformMatrix], [2, 0, 0, 2, 0, 0], 'canvas transform - scaled';
    is-deeply [$gfx.CTM.list], [2, 0, 0, 2, 0, 792 * 2], 'pdf transform - scaled';
    ctx.translate(-5, -15);

    is-deeply [ctx.transformMatrix], [2, 0, 0, 2, -5, -15], 'canvas transform - scaled';
    is-deeply [$gfx.CTM.list], [2, 0, 0, 2, -5, 792 * 2  +  15], 'pdf transform - scaled + translated';

    lives-ok { ctx.strokeRect(20,20, 10,20); }, "basic API call - lives";
    dies-ok  { ctx.strokeRect(10,10, 20, "blah"); }, "incorrect API call - dies";
    dies-ok  { ctx.strokeRect(10,10, 20); }, "incorrect API call - dies";
    dies-ok  { ctx.foo(42) }, "unknown call - dies";
    lives-ok { ctx.font = "24px Arial"; }, 'set font - lives';
    is-deeply $renderer.content-dump, $("q", "0 0 612 792 re", "h", "W", "n", "1 0 0 1 0 792 cm", "1 -791 610 790 re", "s", "20 -40 10 20 re", "s", "2 0 0 2 0 0 cm", "1 0 0 1 -5 15 cm", "20 -40 10 20 re", "s", "/F1 18 Tf"), 'content to-date';

    ctx.fillText("Hello World",50, 40);
    ctx.strokeRect(40,20, 10,25);
    ctx.rotate(.2);
    ctx.fillText("Hello World",50, 40);
    ctx.strokeRect(40,20, 4,25);
    ctx.strokeRect(45,20, 4,25);
}

lives-ok {$pdf.save-as("t/render-pdf-basic.pdf")}, "pdf.save-as";

# also save comparative HTML

my $width = $renderer.width;
my $height = $renderer.height;
my $html = "<html><body>{ $canvas.html( :$width, :$height ) }</body></html>";
"t/render-pdf-basic.html".IO.spurt: $html;

done-testing;
