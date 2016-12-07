use v6;
class HTML::Canvas::To::PDF {

    use Color;
    use HTML::Canvas;
    use PDF::Content::Ops :TextMode, :LineCaps, :LineJoin;
    use PDF::Content;
    has PDF::Content $.gfx handles <content content-dump> is required;
    use PDF::Style::Font;
    has $.width; # canvas height in points
    has $.height; # canvas height in points
    has @!ctm = [1, 0, 0, 1, 0, 0]; #| canvas transform matrix

    submethod TWEAK(:$canvas) {
        unless $!width.defined && $!height.defined {
            my (\x0, \y0, \x1, \y1) = $!gfx.parent.media-box;
            $!width //= x1 - x0;
            $!height //= y1 - y0;
        }
        with $canvas {
            .font-object //= PDF::Style::Font.new;
            .callback.push: self.callback;
        }
    }

    method callback {
        sub ($op, |c) {
            if self.can: "{$op}" {
                self."{$op}"(|c);
            }
            else {
                warn "unimplemented Canvas 2d API call: $op"
            }
        }
    }

    sub pt(Numeric \l) { l }

    method !coords(Numeric \x, Numeric \y) {
        (x, -y);
    }

    # ref: http://stackoverflow.com/questions/1960786/how-do-you-draw-filled-and-unfilled-circles-with-pdf-primitives
    sub draw-circle(\g, Numeric \r, \x, \y) {
        my Numeric \magic = r * 0.551784;
        g.MoveTo(x - r, y);
        g.CurveTo(x - r, y + magic,  x - magic, y + r,  x, y + r);
        g.CurveTo(x + magic, y + r,  x + r, y + magic,  x + r, y);
        g.CurveTo(x + r, y - magic,  x + magic, y - r,  x, y - r);
        g.CurveTo(x - magic, y - r,  x - r, y - magic,  x - r, y);
    }

    method !transform( |c ) {
	my Numeric @tm = PDF::Content::Util::TransformMatrix::transform-matrix( |c );
        @!ctm = PDF::Content::Util::TransformMatrix::multiply(@!ctm, @tm);
	$!gfx.ConcatMatrix( @tm );
    }

    method _start(:$canvas) {
        $canvas.font-object //= PDF::Style::Font.new;
        $!gfx.Save;
        $!gfx.Rectangle(0, 0, pt($!width), pt($!height) );
        $!gfx.ClosePath;
        $!gfx.Clip;
        $!gfx.EndPath;
        $!gfx.transform: :translate[0, $!height];
    }
    method _finish {
        $!gfx.Restore;
    }
    method save { $!gfx.Save }
    method restore { $!gfx.Restore }
    method scale(Numeric \x, Numeric \y) { self!transform(|scale => [x, y]) }
    method rotate(Numeric \r) { self!transform(|rotate => -r) }
    method translate(Numeric \x, Numeric \y) { self!transform(|translate => [x, -y]) }
    method transform(Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
        self!transform(|matrix => [a, b, c, d, e, -f]);
    }
    method setTransform(Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
        my @ctm-inv = PDF::Content::Util::TransformMatrix::inverse(@!ctm);
        my @diff = PDF::Content::Util::TransformMatrix::multiply([a, b, c, d, e, -f], @ctm-inv);
        self!transform( |matrix => @diff )
        unless PDF::Content::Util::TransformMatrix::is-identity(@diff);
    }
    method clearRect(\x, \y, \w, \h) {
        # stub - should etch a clipping path. not paint a white rectangle
        $!gfx.Save;
        $!gfx.FillColor = :DeviceGray[1];
        $!gfx.FillAlpha = 1;
        $!gfx.Rectangle( |self!coords(x, y + h), pt(w), pt(h) );
        $!gfx.Fill;
        $!gfx.Restore;
    }
    method fillRect(\x, \y, \w, \h) {
        unless $!gfx.FillAlpha =~= 0 {
            $!gfx.Rectangle( |self!coords(x, y + h), pt(w), pt(h) );
            $!gfx.Fill;
        }
    }
    method strokeRect(\x, \y, \w, \h) {
        unless $!gfx.StrokeAlpha =~= 0 {
            $!gfx.Rectangle( |self!coords(x, y + h), pt(w), pt(h) );
            $!gfx.CloseStroke;
        }
    }
    method beginPath() { }
    method fill() { $!gfx.Fill; }
    method stroke() { $!gfx.Stroke; }
    method fillStyle(Color $_) {
        $!gfx.FillColor = :DeviceRGB[ .rgb.map: ( */255 ) ];
        $!gfx.FillAlpha = .a / 255;
    }
    method strokeStyle(Color $_) {
        $!gfx.StrokeColor = :DeviceRGB[ .rgb.map: ( */255 ) ];
        $!gfx.StrokeAlpha = .a / 255;
    }
    method lineWidth(Numeric $width, :$canvas) {
        $!gfx.LineWidth = $width;
    }
    method lineCap(Str $cap-name, :$canvas) {
        my LineCaps $lc = %( :butt(ButtCaps), :round(RoundCaps),  :square(SquareCaps)){$cap-name};
        $!gfx.LineCap = $lc;
    }
    method lineJoin(Str $cap-name, :$canvas) {
        my LineJoin $lj = %( :miter(MiterJoin), :round(RoundJoin),  :bevel(BevelJoin)){$cap-name};
        $!gfx.LineJoin = $lj;
    }
    method !text(Str $text, Numeric $x, Numeric $y, :$canvas!, Numeric :$maxWidth) {
        my Numeric $scale;
        if $maxWidth {
            my \width = $canvas.measureText($text).width;
            $scale = 100 * $maxWidth / width
                if width > $maxWidth;
        }

        $!gfx.BeginText;
        $!gfx.HorizScaling = $_ with $scale;
        $!gfx.text-position = self!coords($x, $y);
        my $baseline = $canvas.textBaseline;
        $!gfx.print($text, :$baseline);
        $!gfx.EndText;
    }
    method font(Str $font-style, :$canvas!) {
        my \canvas-font = $canvas.font-object;
        my \pdf-font = $!gfx.use-font(canvas-font.face);

        $!gfx.font = [ pdf-font, canvas-font.em ];
    }
    method textBaseline(Str $baseline) {
    }
    method fillText(Str $text, Numeric $x, Numeric $y, Numeric $maxWidth?, :$canvas!) {
        $!gfx.Save;
        self!text($text, $x, $y, :$maxWidth, :$canvas);
        $!gfx.Restore
    }
    method strokeText(Str $text, Numeric $x, Numeric $y, Numeric $maxWidth?, :$canvas!) {
        $!gfx.Save;
        $!gfx.TextRender = TextMode::OutlineText;
        self!text($text, $x, $y, :$maxWidth, :$canvas);
        $!gfx.Restore
    }
    method measureText(Str $text, :$canvas!) {
        $canvas.measureText($text)
    }
    has %!canvas-cache;
    method !canvas-to-xobject(HTML::Canvas $image, Numeric :$width!, Numeric :$height! ) {
        %!canvas-cache{ ($image.html-id, $width, $height).join('X') } //= do {
            my $form = (require ::('PDF::Content::PDF')).xobject-form( :bbox[0, 0, $width, $height] );
            my $renderer = self.new: :gfx($form.gfx), :$width, :$height;
            $image.render($renderer);
            $form.finish;
            $form
        };
    }
    my subset CanvasOrXObject where HTML::Canvas|Hash;
    multi method drawImage( CanvasOrXObject $image, Numeric \sx, Numeric \sy, Numeric \sw, Numeric \sh, Numeric \dx, Numeric \dy, Numeric \dw, Numeric \dh) {
        unless sw =~= 0 || sh =~= 0 {
            $!gfx.Save;

            # position at top right of visible area
            $!gfx.transform: :translate(self!coords(dx, dy));
            # clip to visible area
            $!gfx.Rectangle: pt(0), pt(-dh), pt(dw), pt(dh);
            $!gfx.ClosePath;
            $!gfx.Clip;
            $!gfx.EndPath;

            my \x-scale = dw / sw;
            my \y-scale = dh / sh;
            $!gfx.transform: :translate[ -sx * x-scale, sy * y-scale ]
                if sx || sy;

            my $xobject;
            my $width;
            my $height;

            if $image.isa(HTML::Canvas) {
                $width = $image.html-width || dw;
                $height = $image.html-height || dh;
                $xobject = self!canvas-to-xobject($image, :$width, :$height);
                $width  *= x-scale;
                $height *= y-scale;
            }
            else {
                $width = x-scale * $image.width;
                $height = y-scale * $image.height;
                $xobject = $image;
            }

            $!gfx.do: $xobject, :valign<top>, :$width, :$height;

            $!gfx.Restore;
        }
    }
    multi method drawImage(CanvasOrXObject $image, Numeric $dx, Numeric $dy, Numeric $dw?, Numeric $dh?) is default {
        my $xobject;
        if $image.isa(HTML::Canvas) {
            my $width = $image.html-width // $dw;
            my $height = $image.html-height // $dh;
            $xobject = self!canvas-to-xobject($image, :$width, :$height);
        }
        else {
            $xobject = $image;
        }

        my %opt = :valign<top>;
        %opt<width>  = $_ with $dw;
        %opt<height> = $_ with $dh;

        $!gfx.do($xobject, |self!coords($dx, $dy), |%opt);
    }
    method getLineDash() {}
    method setLineDash(List $pattern, :$canvas) {
        $!gfx.SetDashPattern($pattern, $canvas.lineDashOffset)
    }
    method closePath() { $!gfx.ClosePath }
    method moveTo(Numeric \x, Numeric \y) { $!gfx.MoveTo( |self!coords(x, y)) }
    method lineTo(Numeric \x, Numeric \y) {
        $!gfx.LineTo( |self!coords(x, y));
    }
    method quadraticCurveTo(Numeric \cp1x, Numeric \cp1y, Numeric \x, Numeric \y) {
        my \cp2x = cp1x + 2/3 * (x - cp1x);
        my \cp2y = cp1y + 2/3 * (y - cp1y);
        $!gfx.CurveTo( |self!coords(cp1x, cp1y), |self!coords(cp2x, cp2y), |self!coords(x, y) );
     }
     method bezierCurveTo(Numeric \cp1x, Numeric \cp1y, Numeric \cp2x, Numeric \cp2y, Numeric \x, Numeric \y) {
        $!gfx.CurveTo( |self!coords(cp1x, cp1y), |self!coords(cp2x, cp2y), |self!coords(x, y) );
    }
    method rect(\x, \y, \w, \h) {
        $!gfx.Rectangle( |self!coords(x, y + h), pt(w), pt(h) );
        $!gfx.ClosePath;
    }
    method arc(Numeric \x, Numeric \y, Numeric \r, Numeric \startAngle, Numeric \endAngle, Bool $anti-clockwise?) {
        # stub. ignores start and end angle; draws a circle
        warn "todo: arc start/end angles"
            unless endAngle - startAngle =~= 2 * pi;
        draw-circle($!gfx, r, |self!coords(x, y));
    }

}
