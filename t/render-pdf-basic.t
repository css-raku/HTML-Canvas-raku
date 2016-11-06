use v6;
use Test;

use PDF::Content::PDF;
use HTML::Canvas;
use HTML::Canvas::Render::PDF;
use HTML::Canvas::Render::PDF::Font;

my HTML::Canvas::Render::PDF::Font $font-object .= new;
my  PDF::Content::PDF $pdf .= new;
my $gfx = $pdf.add-page.gfx(:!strict);
my HTML::Canvas::Render::PDF $renderer .= new: :$gfx;
is $renderer.width, 612, 'renderer default width';
is $renderer.height, 792, 'rendered default height';
my $callback = $renderer.callback;
my HTML::Canvas $canvas .= new(:$callback, :$font-object);

$canvas.scale( 2.0, 2.0);
$canvas.translate(5, 5);

is-deeply [$canvas.transformMatrix], [2, 0, 0, 2, 5, 5], 'canvas transform';
is-deeply [$gfx.CTM.list], [2, 0, 0, 2, 5, -5], 'pdf transform';

lives-ok { $canvas.strokeRect(20,20, 10,20); }, "basic API call - lives";
dies-ok  { $canvas.strokeRect(10,10, 20, "blah"); }, "incorrect API call - dies";
dies-ok  { $canvas.strokeRect(10,10, 20); }, "incorrect API call - dies";
dies-ok  { $canvas.foo(42) }, "unknown call - dies";
lives-ok { $canvas.font = "32px Arial"; }, 'set font - lives';
is-deeply $renderer.content.lines, $("2 0 0 2 0 0 cm", "1 0 0 1 5 -5 cm", "20 361 10 20 re", "s", "/F1 24 Tf"), 'renderer.content';

lives-ok {$pdf.save-as("t/render-pdf-basic.pdf")}, "pdf.save-as";

done-testing;
