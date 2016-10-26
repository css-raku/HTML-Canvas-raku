use v6;
use Test;

use PDF::Content;
use HTML::Canvas;
use HTML::Canvas::Render::PDF;

my PDF::Content $gfx .= new: :!strict;
my HTML::Canvas::Render::PDF $renderer .= new( :$gfx, :height(100) );
my $callback = $renderer.callback;
my HTML::Canvas $canvas .= new(:$callback);

$canvas.scale( 2.0, 3.0);

lives-ok { $canvas.strokeRect(100,100, 50,20); }, "basic API call - lives";
dies-ok  { $canvas.strokeRect(100,100, 50, "blah"); }, "incorrect API call - dies";
dies-ok  { $canvas.strokeRect(100,100, 50); }, "incorrect API call - dies";
dies-ok  { $canvas.foo(42) }, "unknown call - dies";

is-deeply $renderer.content.lines, $("2 0 0 3 0 0 cm", "75 25 37.5 15 re", "s"), 'renderer.content';

done-testing;
