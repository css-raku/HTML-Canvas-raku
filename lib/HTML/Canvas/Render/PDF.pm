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

    constant Scale = 1.0;
    sub pt(Numeric \l) { l * Scale }
    method !pt-y(Numeric \l) { $!height - l * Scale }

    my %Dispatch = BEGIN %(
        scale     => method (Numeric \x, Numeric \y) { $!gfx.transform(|scale => [x, y]) },
        rotate    => method (Numeric \angle) { $!gfx.transform(|rotate => [ angle, ]) },
        translate => method (Numeric \x, Numeric \y) { $!gfx.transform(|translate => [x, y]) },
        transform => method (Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
            $!gfx.ConcatMatrix(a, b, c, d, e, f);
        },
        setTransform => method (Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
            $!gfx.GraphicsMatrix = [a, b, c, d, e, f];
        },
        font => method (Str \font-expr) {
            with self.font-object {
                .css-font-prop = font-expr;
                $!gfx.font = [ .face, .em ];
            }
        },
        rect => method (\x, \y, \w, \h) {
            unless $!gfx.fillAlpha =~= 0 {
                $!gfx.Rectangle( pt(x), self!pt-y(y + h), pt(w), pt(h) );
                $!gfx.ClosePath;
            }
        },
        strokeRect => method (\x, \y, \w, \h) {
            $!gfx.Rectangle( pt(x), self!pt-y(y + h), pt(w), pt(h) );
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

}
