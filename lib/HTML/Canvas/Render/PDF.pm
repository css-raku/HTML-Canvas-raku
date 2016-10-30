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
                    ?? warn "unimplemented Canvas js call: $op"
                    !! die "unknown Canvas 2d API call: $op";    
            }
        }
    }

    constant Pt2Px = 0.75;       # 1px = 0.75 pt;
    sub pt(Numeric \l) { l * Pt2Px }
    method !pt-y(Numeric \l) { $!height - l * Pt2Px }

    my %Dispatch = BEGIN %(
        scale => method (*@args) { $!gfx.transform(|scale => @args) },
        rotate => method (*@args) { $!gfx.transform(|rotate => @args) },
        translate => method (*@args) { $!gfx.transform(|translate => @args) },
        transform => method (*@args) { $!gfx.ConcatMatrix(@args) },
        font => method (Str \font-expr) {
            with self.font-object {
                .css-font-prop = font-expr;
                $!gfx.font = [ .face, .em ];
            }
        },
        rect => method (\x, \y, \w, \h) {
            unless $!gfx.fillAlpha =~= 0 {
                $!gfx.Rectangle( pt(x), self!pt-y(y), pt(w), pt(h) );
                $!gfx.ClosePath;
            }
        },
        strokeRect => method (\x, \y, \w, \h) {
            $!gfx.Rectangle( pt(x), self!pt-y(y), pt(w), pt(h) );
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
