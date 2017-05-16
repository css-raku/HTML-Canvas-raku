# perl6-HTML-Canvas

This a a lighweight module for composing HTML-5 canvases.

```
use v6;
# Create a simple Canvas. Save as HTML

use HTML::Canvas;
my HTML::Canvas $canvas .= new;

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
my $html = "<html><body>{ $canvas.to-html( :width(250), :height(150) ) }</body></html>";
"t/canvas-demo.html".IO.spurt: $html;
```
