use v6;
use Test;

use HTML::Canvas;

my HTML::Canvas $canvas .= new;

lives-ok { $canvas.rect(100,100, 50,20); }, "basic API call - lives";
dies-ok { $canvas.rect(100,100, 50, "blah"); }, "incorrect API call - dies";
dies-ok { $canvas.rect(100,100, 50); }, "incorrect API call - dies";
dies-ok { $canvas.foo(42) }, "unknown call - dies";

is-deeply $canvas.calls, [ rect => [100,100,50,20], ], '.calls';

done-testing;
