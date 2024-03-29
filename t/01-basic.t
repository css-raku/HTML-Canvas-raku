use v6;
use Test;
plan 8;

use HTML::Canvas;
use HTML::Canvas::To::Cairo;
use CSS::Font::Descriptor;
use Cairo;

my CSS::Font::Descriptor $arial .= new: :font-family<arial>, :src<url(resources/font/FreeMono.ttf)>;
my HTML::Canvas $canvas .= new: :font-face[$arial];
lives-ok { $canvas.rect(100,100, 50,20); }, "basic API call - lives";
dies-ok  { $canvas.rect(100,100, 50, "blah"); }, "incorrect API call - dies";
dies-ok  { $canvas.rect(100,100, 50); }, "incorrect API call - dies";
dies-ok  { $canvas.foo(42) }, "unknown call - dies";

my @keys = $canvas.keys;
ok @keys.first: 'scale';
$canvas.fill;
$canvas<scale>(2.0, 3.0);
$canvas<font> = "30px Arial";
$canvas.fillText("Hello World",10,50);

is-deeply [$canvas.transformMatrix], [2.0, 0.0, 0.0, 3.0, 0, 0], '.TransformMatrix';
is-deeply [$canvas.calls], [ :rect[100,100,50,20], :fill[], :scale[2.0, 3.0], :font[ "30px Arial", ], :fillText['Hello World', 10,50], ], '.calls';

is-deeply $canvas.js.lines, ('ctx.rect(100, 100, 50, 20);', 'ctx.fill();', 'ctx.scale(2.0, 3.0);', 'ctx.font = "30px Arial";', 'ctx.fillText("Hello World", 10, 50);'), '.js';

# save canvas as PNG
my Cairo::Surface $surface = $canvas.image;
$surface.write_png: "tmp/01-basic.png";

done-testing;
