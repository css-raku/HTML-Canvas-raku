use v6;
class HTML::Canvas::To::PDF {

    use Color;
    use HTML::Canvas;
    use HTML::Canvas::Gradient;
    use HTML::Canvas::Pattern;
    use PDF:ver(v0.2.1..*);
    use PDF::Content:ver(v0.0.1..*);
    use PDF::Content::Ops :TextMode, :LineCaps, :LineJoin;
    has PDF::Content $.gfx handles <content content-dump> is required;
    use PDF::Style::Font:ver(v0.0.1..*);
    has $.width; # canvas height in points
    has $.height; # canvas height in points
    has @!ctm = [1, 0, 0, 1, 0, 0]; #| canvas transform matrix

    submethod TWEAK(:$canvas) {
        $!width  //= $!gfx.parent.width;
        $!height //= $!gfx.parent.height;

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

    method !transform( |c ) {
	my Numeric @tm = PDF::Content::Util::TransformMatrix::transform-matrix( :matrix(@!ctm), |c );
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
    method fillRect(\x, \y, \w, \h, :$canvas!) {
        self!setup-fill($canvas);
        unless $!gfx.FillAlpha =~= 0 {
            $!gfx.Rectangle( |self!coords(x, y + h), pt(w), pt(h) );
            $!gfx.Fill;
        }
    }
    method strokeRect(\x, \y, \w, \h, :$canvas!) {
        self!setup-stroke($canvas);
        unless $!gfx.StrokeAlpha =~= 0 {
            $!gfx.Rectangle( |self!coords(x, y + h), pt(w), pt(h) );
            $!gfx.CloseStroke;
        }
    }
    method beginPath() { }
    method fill(:$canvas!) {
        self!setup-fill($canvas);
        $!gfx.Fill;
    }
    method stroke(:$canvas!) {
        self!setup-stroke($canvas);
        $!gfx.Stroke;
    }
    method fillStyle($_) {}
    method !pdf {require PDF::Lite:ver(v0.0.1..*)}
    method !make-pattern(HTML::Canvas::Pattern $pattern --> Pair) {
        my Bool $repeat-x = True;
        my Bool $repeat-y = True;
        given $pattern.repetition {
            when 'repeat-y' { $repeat-x = False }
            when 'repeat-x' { $repeat-y = False }
            when 'no-repeat' { $repeat-x = $repeat-y = False }
        }
        my $image = $pattern.image;
        my Numeric $width = $image.width;
        my Numeric $height = $image.height;
        my $XStep = $width;
        my $YStep = $height;
        my @Matrix = $!gfx.CTM.list;

        my constant BigStep = 1999;
        unless $repeat-x {
            # step outside box in X direction
            $XStep += BigStep;
        }
        unless $repeat-y {
            # step outside box in Y direction
            $YStep += BigStep;
            @Matrix = PDF::Content::Util::TransformMatrix::transform-matrix( :matrix(@Matrix), :translate[0, BigStep] );
        }
        my $Pattern = self!pdf.tiling-pattern(:BBox[0, 0, $width, $height], :@Matrix, :$XStep, :$YStep );
        $Pattern.graphics: {
            .do($image, 0, 0, :$width, :$height );
        }
        $Pattern.finish;
        Pattern => $!gfx.resource-key($Pattern);
    }
    method !setup-fill($canvas) {
        given $canvas.fillStyle {
            when HTML::Canvas::Pattern {
                $!gfx.FillAlpha = 1.0;
                $!gfx.FillColor = self!make-pattern($_);
            }
            when HTML::Canvas::Gradient {
                warn "gradient fill - nyi";
            }
            when Color {
                $!gfx.FillColor = :DeviceRGB[ .rgb.map: ( */255 ) ];
                $!gfx.FillAlpha = .a / 255;
            }
        }
    } 
    method !setup-stroke($canvas) {
        given $canvas.strokeStyle {
            when HTML::Canvas::Pattern {
                $!gfx.StrokeAlpha = 1.0;
                $!gfx.StrokeColor = self!make-pattern($_);
            }
            when HTML::Canvas::Gradient {
                warn "gradient stroke - nyi";
            }
            when Color {
                $!gfx.StrokeColor = :DeviceRGB[ .rgb.map: ( */255 ) ];
                $!gfx.StrokeAlpha = .a / 255;
            }
        }
    } 
    method strokeStyle($_) {}
    method lineWidth(Numeric $width) {
        $!gfx.LineWidth = $width;
    }
    method lineCap(Str $cap-name) {
        my LineCaps $lc = %( :butt(ButtCaps), :round(RoundCaps),  :square(SquareCaps)){$cap-name};
        $!gfx.LineCap = $lc;
    }
    method lineJoin(Str $cap-name) {
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
        my HTML::Canvas::textAlignment $align = do given $canvas.textAlign {
            when 'start' { $canvas.direction eq 'ltr' ?? 'left' !! 'right' }
            when 'end'   { $canvas.direction eq 'rtl' ?? 'left' !! 'right' }
            default { $_ }
        }

        $!gfx.print($text, :$align, :$baseline);
        $!gfx.EndText;
    }
    method font(Str $font-style, :$canvas!) {
        my \canvas-font = $canvas.font-object;
        my \pdf-font = $!gfx.use-font(canvas-font.face);
        $!gfx.font = [ pdf-font, $canvas.adjusted-font-size(canvas-font.em) ];
    }
    method textBaseline(Str $_) {}
    method textAlign(Str $_) {}
    method direction(Str $_) {}
    method fillText(Str $text, Numeric $x, Numeric $y, Numeric $maxWidth?, :$canvas!) {
        self!setup-fill($canvas);
        $!gfx.Save;
        self!text($text, $x, $y, :$maxWidth, :$canvas);
        $!gfx.Restore
    }
    method strokeText(Str $text, Numeric $x, Numeric $y, Numeric $maxWidth?, :$canvas!) {
        self!setup-stroke($canvas);
        $!gfx.Save;
        $!gfx.TextRender = TextMode::OutlineText;
        self!text($text, $x, $y, :$maxWidth, :$canvas);
        $!gfx.Restore
    }
    method measureText(Str $text, :$canvas!) {
    }
    has %!canvas-cache;
    method !canvas-to-xobject(HTML::Canvas $image, Numeric :$width!, Numeric :$height! ) {
        %!canvas-cache{ ($image.html-id, $width, $height).join('X') } //= do {
            my $form = (require ::('PDF::Lite')).xobject-form( :bbox[0, 0, $width, $height] );
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

    #| Compute all four points for an arc that subtends the same total angle
    #| but is centered on the X-axis
    sub createSmallArc(Numeric \r, Numeric \a1, Numeric \a2) {
        # adapted from http://hansmuller-flex.blogspot.co.nz/2011/04/approximating-circular-arc-with-cubic.html
        # courtesy of Hans Muller
        my Numeric \a = (a2 - a1) / 2.0;

        my Numeric \x4 = r * cos(a);
        my Numeric \y4 = r * sin(a);
        my Numeric \x1 = x4;
        my Numeric \y1 = -y4;

        my Numeric \k = 0.5522847498;
        my Numeric \f = k * tan(a);

        my Numeric \x2 = x1 + f * y4;
        my Numeric \y2 = y1 + f * x4;
        my Numeric \x3 = x2;
        my Numeric \y3 = -y2;

        # Find the arc points actual locations by computing x1,y1 and x4,y4
        # and rotating the control points by a + a1

        my Numeric \ar = a + a1;
        my Numeric \cos_ar = cos(ar);
        my Numeric \sin_ar = sin(ar);

        return {
            :x1(r * cos(a1)),
            :y1(r * sin(a1)),
            :x2(x2 * cos_ar - y2 * sin_ar),
            :y2(x2 * sin_ar + y2 * cos_ar),
            :x3(x3 * cos_ar - y3 * sin_ar),
            :y3(x3 * sin_ar + y3 * cos_ar),
            :x4(r * cos(a2)),
            :y4(r * sin(a2)),
        };
    }

    constant @Quadrant = [ 0, pi/2, pi, 3 * pi/2, 2 * pi ];
    sub find-quadrant($a) {
        my \a = $a % (2*pi);
        (0..3).first: { @Quadrant[$_] - $*TOLERANCE <= a <= @Quadrant[$_+1] + $*TOLERANCE };
    }
    method arc(Numeric \x, Numeric \y, Numeric \r,
               Numeric $startAngle is copy, Numeric $endAngle is copy, Bool $anti-clockwise?) {

        if $anti-clockwise {
            $endAngle = $startAngle
                if $startAngle - $endAngle > 2 * pi;
        }
        else {
            $endAngle = $startAngle + 2 * pi
                if $endAngle - $startAngle > 2 * pi;
        }

        # break circle down into semicircle quadrants, which
        # are then drawn with individual PDF CurveTo operations
        my $start-q = find-quadrant($startAngle);
        my $end-q   = find-quadrant($endAngle);

        my $n = $end-q >= $start-q
            ?? $end-q - $start-q
            !! (4 - $start-q) + $end-q;

        $n ||= do {
            # further analyse start/end in the same quadrant
            # ~ full circle, or small short arc?
            my \theta = $endAngle - $startAngle;
            theta < pi ?? 0 !! 4;
        }

        if $anti-clockwise {
            # draw the compilmentry arc
            ($startAngle, $endAngle) = ($endAngle, $startAngle);
            ($start-q, $end-q) = ($end-q, $start-q);
            $n = 4 - $n;
        }

        my @segments = (0..$n).map: {
            my \starting = $_ == 0;
            my \ending = $_ == $n;
            my \i = ($start-q + $_) % 4;
            my \a1 = starting ?? $startAngle !! @Quadrant[i];
            my \a2 = ending  ?? $endAngle    !! @Quadrant[i+1];
            [a1, a2];
        }

        my @arcs = @segments        \
            .grep({.[0] !=~= [.1]}) \
            .map: { createSmallArc(r, .[0], .[1]); };

        $!gfx.MoveTo( |self!coords(x + .<x1>, y + .<y1>) )
            with @arcs[0];

        for @arcs {
            $!gfx.CurveTo( |self!coords(x + .<x2>, y + .<y2>),
                           |self!coords(x + .<x3>, y + .<y3>),
                           |self!coords(x + .<x4>, y + .<y4>),
                         );
        }
    }

}
