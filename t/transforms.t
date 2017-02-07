use v6;
use Test;
plan 4;

use PDF::Lite;
use PDF::Content::Image::PNG;
use HTML::Canvas;
use HTML::Canvas::To::PDF;

my PDF::Lite $pdf .= new;
my $page-no;
my @html-body;
my @sheets;

my $y = 0;
my \h = 20;
my \pad = 10;
my \textHeight = 20;
my $measured-text;

sub test-page(&markup) {
    my HTML::Canvas $canvas .= new;
    my $gfx = $pdf.add-page.gfx;
    $gfx.comment-ops = True;
    my $feed = HTML::Canvas::To::PDF.new: :$gfx, :$canvas;
    my Bool $clean = True;
    $page-no++;
        $canvas.context(
            -> \ctx {
                $y = 0;
                ctx.font = "20pt times";
                &markup(ctx, $gfx);
            });

    try {
        CATCH {
            default {
                warn "stopped on page $page-no: {.message}";
                $clean = False;
                # flush
                $canvas.beginPath if $canvas.subpath;
                $canvas.restore while $canvas.gsave;
                $canvas._finish;
            }
        }
    }

    ok $clean, "completion of page $page-no";
    my $width = $feed.width;
    my $height = $feed.height;
    @html-body.push: "<hr/>" ~ $canvas.to-html( :$width, :$height );
    @sheets.push: $canvas;
}

my \image = PDF::Content::Image::PNG.open("t/images/crosshair-100x100.jpg");

@html-body.push: HTML::Canvas.to-html: image, :style("visibility:hidden");

test-page(
    -> \ctx, \gfx {
        constant h = 100;
        my $html-transform;         
        my $gfx-transform;         

        ctx.fillText("Testing Transforms", 20, $y += textHeight);
        $y += pad + 10;
        my \pat = ctx.createPattern(image,'repeat');

      for ([:translate(100,50), :scale(2,2)],
           [:scale(2,2), :translate(150, 50) ],
          ) -> \t {
          ctx.save(); {
              ctx."{.key}"(|.value) for t.list;
              $html-transform = ctx.transformMatrix.list;
              $gfx-transform = gfx.CTM;
              ctx.font = "italic 5pt courier";
              ctx.fillText([$html-transform.list].perl, 0, 0);
              ctx.strokeStyle = 'red';
              ctx.fillStyle = pat;
              ctx.fillRect(0,10,75,100);
              ctx.strokeRect(0,10,75,100);
          }; ctx.restore();

          ctx.save(); {
              ctx.setTransform(|$html-transform);
              is-deeply gfx.CTM, $gfx-transform, 'set-transform';
          }; ctx.restore();

          $y += h + pad;
      }
});

lives-ok {$pdf.save-as("t/transforms.pdf")}, "pdf.save-as";

my $html = "<html><body>" ~ @html-body.join ~ "</body></html>";

"t/transforms.html".IO.spurt: $html;

done-testing;
