use Test;
plan 1;
use HTML::Canvas;
use HTML::Canvas::Image;
use Cairo;
my @html-body;

my HTML::Canvas $canvas .= new;

sub draw-line(\ctx, $y) {
    ctx.strokeStyle = '#d99';
    ctx.beginPath();
    ctx.moveTo(20,$y);
    ctx.lineTo(300, $y);
    ctx.stroke();
}

sub place-text(\ctx) {
    my $y = 10;
    draw-line(ctx, $y);
    ctx.textBaseline = 'top';
    ctx.fillText("TopText", 10, $y);
    ctx.textBaseline = 'bottom';
    ctx.fillText("Bottom", 100, $y);
    ctx.textBaseline = 'middle';
    ctx.fillText("Middle", 200, $y);
}


$canvas.context: -> \ctx {
    my HTML::Canvas::Image \image .= open("t/images/crosshair-100x100.png");
    @html-body.push: $canvas.to-html: image, :style("visibility:hidden");
    ctx.font = '10pt ariel';
    ctx.translate(0, 20);
    place-text(ctx);

    ctx.translate(0, 50);
    ctx.font = '20pt ariel';
    place-text(ctx);

    ctx.translate(0, 80);
    ctx.font = '30pt ariel';
    place-text(ctx);

    # drawImage 3 arguments
    #                    sx, sy,    sw,  sh,    dx,  dy,   dw,  dh
    ctx.drawImage(image,                        10, 100,           );
    ctx.drawImage(image,                       120, 100,           );
    draw-line(ctx, 100);

    # drawImage 5 arguments
    #                    sx, sy,    sw,  sh,    dx,  dy,   dw,  dh
    ctx.drawImage(image,                        10, 200,   100, 100);
    ctx.drawImage(image,                       120, 200,   100, 100);
    draw-line(ctx, 200);

    # drawImage 9 arguments
    #                    sx, sy,    sw,  sh,    dx,  dy,   dw,  dh
    ctx.drawImage(image,  0,  0,   100, 100,    10, 300,   100, 100);
    ctx.drawImage(image,  0,  0,   110, 110,   120, 300,   100, 100);
    ctx.drawImage(image,  10,10,   110, 110,   230, 300,   100, 100);
    draw-line(ctx, 300);
}

lives-ok {$canvas.image.write_png: "tmp/placement.png"};

@html-body.push: "<hr/>" ~ $canvas.to-html( :width(612), :height(792) );
my $html = "<html><body>" ~ @html-body.join ~ "</body></html>";
"t/placement.html".IO.spurt: $html;
done-testing;
