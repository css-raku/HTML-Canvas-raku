use v6;
class HTML::Canvas::Render::PDF {

    use HTML::Canvas :API;
    use PDF::Content;
    has PDF::Content $.gfx handles <content> is required;
    has $.height is required; # canvas height in points
    has $.font-object is required;

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
        #| translate back to absolute cordinates
        my \ctm = $!gfx.CTM;
        my (\x1, \y1) = PDF::Content::Util::TransformMatrix::dot(ctm, x, y);
        PDF::Content::Util::TransformMatrix::inverse-dot(ctm, x1, $!height - y1);
    }

    my %Dispatch = BEGIN %(
        scale     => method (Numeric \x, Numeric \y) { $!gfx.transform(|scale => [x, y]) },
        rotate    => method (Numeric \angle) { $!gfx.transform(|rotate => [ angle, ]) },
        translate => method (Numeric \x, Numeric \y) { $!gfx.transform(|translate => [x, -y]) },
        transform => method (Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
            $!gfx.ConcatMatrix(a, b, c, d, e, -f);
        },
        setTransform => method (Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
            $!gfx.CTM = [a, b, c, d, e, -f];
        },
        fillText => method (Str $text, Numeric $x, Numeric $y, Numeric $maxWidth?) {
            self.font;
            my $scale;
            if $maxWidth && $maxWidth > 0 {
                my Numeric \width = .face.stringwidth($text, .em) with $!font-object;
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
        font => method (Str $font-style?) {
            my \pdf-font = $!gfx.use-font($!font-object.face);

            with $font-style {
                $!font-object.css-font-prop = $_;
                $!gfx.font = [ pdf-font, $!font-object.em ];
            }
            else {
                $!gfx.font //= [ pdf-font, $!font-object.em ];
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
