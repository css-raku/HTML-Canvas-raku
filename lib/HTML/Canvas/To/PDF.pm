use v6;
class HTML::Canvas::To::PDF {

    use HTML::Canvas :API;
    use PDF::Content;
    has PDF::Content $.gfx handles <content content-dump> is required;
    use PDF::Style::Font;
    has $.width; # canvas height in points
    has $.height; # canvas height in points
    has @!ctm = [1, 0, 0, 1, 0, 0]; #| canvas transform matrix

    submethod TWEAK {
        unless $!width.defined && $!height.defined {
            my (\x0, \y0, \x1, \y1) = $!gfx.parent.media-box;
            $!width //= x1 - x0;
            $!height //= y1 - y0;
        }
    }

    method callback {
        sub ($op, |c) {
            if self.can: "{$op}" {
                self."{$op}"(|c);
            }
            else {
                %API{$op}:exists
                    ?? warn "unimplemented Canvas 2d API call: $op"
                    !! die "unknown Canvas 2d API call: $op";    
            }
        }
    }

    sub pt(Numeric \l) { l }

    method !coords(Numeric \x, Numeric \y) {
        (x, -y);
    }

    # ref: http://stackoverflow.com/questions/1960786/how-do-you-draw-filled-and-unfilled-circles-with-pdf-primitives
    sub draw-circle(\g, Numeric \r) {
        my Numeric \magic = r * 0.551784;
        g.MoveTo(-r, 0);
        g.CurveTo(-r, magic, -magic, r,  0, r);
        g.CurveTo(magic, r,  r, magic,  r, 0);
        g.CurveTo(r, -magic,  magic, -r,  0, -r);
        g.CurveTo(-magic, -r,  -r, -magic,  -r, 0);
    }

    method !transform( |c ) {
	my Numeric @tm = PDF::Content::Util::TransformMatrix::transform-matrix( |c );
        @!ctm = PDF::Content::Util::TransformMatrix::multiply(@!ctm, @tm);
	$!gfx.ConcatMatrix( @tm );
    }

    my %Dispatch = BEGIN %(
        _start    => method (:$canvas) {
            $canvas.font-object //= PDF::Style::Font.new;
            $!gfx.Save;
            $!gfx.Rectangle(0, 0, pt($!width), pt($!height) );
            $!gfx.ClosePath;
            $!gfx.Clip;
            $!gfx.EndPath;
            $!gfx.transform: :translate[0, $!height];
        },
        _finish   => method {
            $!gfx.Restore;
        },
        scale     => method (Numeric \x, Numeric \y) { self!transform(|scale => [x, y]) },
        rotate    => method (Numeric \r) {
            self!transform(|rotate => -r);
        },
        translate => method (Numeric \x, Numeric \y) { self!transform(|translate => [x, -y]) },
        transform => method (Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
            self!transform(|matrix => [a, b, c, d, e, -f]);
        },
        setTransform => method (Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
            my @ctm-inv = PDF::Content::Util::TransformMatrix::inverse(@!ctm);
            my @diff = PDF::Content::Util::TransformMatrix::multiply([a, b, c, d, e, -f], @ctm-inv);
                self!transform( |matrix => @diff )
                    unless PDF::Content::Util::TransformMatrix::is-identity(@diff);
        },
        arc => method (Numeric \x, Numeric \y, Numeric \r, Numeric \startAngle, Numeric \endAngle, Bool $anti-clockwise?) {
            # stub. ignores start and end angle; draws a circle
            warn "todo: arc start/end angles"
                unless endAngle - startAngle =~= 2 * pi;
            $!gfx.ConcatMatrix:  PDF::Content::Util::TransformMatrix::translate(|self!coords(x, y) );
            draw-circle($!gfx, r);
        },
        beginPath => method () {
            $!gfx.Save;
        },
        stroke => method () {
            $!gfx.Stroke;
            $!gfx.Restore;
        },
        fillText => method (Str $text, Numeric $x, Numeric $y, Numeric $maxWidth?, :$canvas!) {
            self.font(:$canvas);
            my $scale;
            if $maxWidth {
                my \width = $canvas.measureText($text).width;
                $scale = 100 * $maxWidth / width
                    if width > $maxWidth;
            }

            $!gfx.Save;
            $!gfx.BeginText;
            $!gfx.HorizScaling = $_ with $scale;
            $!gfx.text-position = self!coords($x, $y);
            $!gfx.print($text);
            $!gfx.EndText;
            $!gfx.Restore
        },
        measureText => method (Str $text, :$canvas!) {
            $canvas.measureText($text)
        },
        font => method (Str $font-style?, :$canvas!) {
            my \canvas-font = $canvas.font-object;
            canvas-font.font-style = $_ with $font-style;
            my \pdf-font = $!gfx.use-font(canvas-font.face);

            with $font-style {
                $!gfx.font = [ pdf-font, canvas-font.em ];
            }
            else {
                $!gfx.font //= [ pdf-font, canvas-font.em ];
            }
        },
        rect => method (\x, \y, \w, \h) {
            unless $!gfx.fillAlpha =~= 0 {
                $!gfx.Rectangle( |self!coords(x, y + h), pt(w), pt(h) );
                $!gfx.ClosePath;
            }
        },
        strokeRect => method (\x, \y, \w, \h) {
            $!gfx.Rectangle( |self!coords(x, y + h), pt(w), pt(h) );
            $!gfx.CloseStroke;
        },
    );

    method can(\name) {
        my @can = callsame;
        unless @can {
            with %Dispatch{name} {
                @can.push: $_;
                self.^add_method( name, @can[0] );
            }
        }
        @can;
    }

    method dispatch:<.?>(\name, |c) is raw {
        self.can(name) ?? self."{name}"(|c) !! Nil
    }
    method FALLBACK(\name, |c) {
        self.can(name)
            ?? self."{name}"(|c)
            !! die X::Method::NotFound.new( :method(name), :typename(self.^name) );
    }

}
