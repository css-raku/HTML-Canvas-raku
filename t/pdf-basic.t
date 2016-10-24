use v6;
use Test;

use PDF::Content;
use HTML::Canvas;
use HTML::Canvas::PDF;

my PDF::Content $gfx .= new: :!strict;
my HTML::Canvas::PDF $canvas-pdf .= new( :$gfx );
my $callback = $canvas-pdf.renderer;
my HTML::Canvas $canvas .= new(:$callback);

$canvas.scale( 2.0, 3.0);

lives-ok { $canvas.rect(100,100, 50,20); }, "basic API call - lives";
dies-ok  { $canvas.rect(100,100, 50, "blah"); }, "incorrect API call - dies";
dies-ok  { $canvas.rect(100,100, 50); }, "incorrect API call - dies";
dies-ok  { $canvas.foo(42) }, "unknown call - dies";

todo "map rectangle coordinates";
is-deeply $canvas-pdf.content.lines, $("2 0 0 3 0 0 cm", "100 100 50 20 re", "s");

done-testing;
