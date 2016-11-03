use v6;
use Test;

use PDF::Content;
use HTML::Canvas;
use HTML::Canvas::Render::PDF;

my $font-object = class { }.new;
my PDF::Content $gfx .= new: :!strict;
my HTML::Canvas::Render::PDF $renderer .= new( :$gfx, :height(150), :$font-object );
my $callback = $renderer.callback;
my HTML::Canvas $canvas .= new(:$callback);

$canvas.scale( 2.0, 2.0);
$canvas.translate(5, 5);

is-deeply [$canvas.transformMatrix], [2, 0, 0, 2, 5, 5], 'canvas transform';
is-deeply [$gfx.GraphicsMatrix.list], [2, 0, 0, 2, 5, -5], 'pdf transform';

lives-ok { $canvas.strokeRect(20,20, 10,20); }, "basic API call - lives";
dies-ok  { $canvas.strokeRect(10,10, 20, "blah"); }, "incorrect API call - dies";
dies-ok  { $canvas.strokeRect(10,10, 20); }, "incorrect API call - dies";
dies-ok  { $canvas.foo(42) }, "unknown call - dies";
todo "font stubbing";
lives-ok {$canvas.font = "30px Arial"};
is-deeply $renderer.content.lines, $("2 0 0 2 0 0 cm", "1 0 0 1 5 -5 cm", "20 40 10 20 re", "s"), 'renderer.content';

done-testing;
