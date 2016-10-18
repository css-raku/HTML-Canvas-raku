use v6;

class HTML::Canvas {
    has Numeric @.TransformationMatrix[6] is rw = [ 1, 0, 0, 1, 0, 0, ];
    has @.calls;
    has Routine &.renderer;

    has Method %API = BEGIN %(
        :arc(method (Numeric $x, Numeric $y, Numeric $radius, Numeric $startAngle, Numeric $endAngle, Bool $counterClockwise?) { }),
        :beginPath(method () {}),
        :rect(method (Numeric $x, Numeric $y, Numeric $w, Numeric $h) { }),
        :fillText(method (Str $text, Numeric $x, Numeric $y, Numeric $max-width?) { }),
        :stroke(method () {}),
    );

    method can(Str $meth-name) {
        my @meth = callsame;
        if !@meth {
            with %API{$meth-name} -> &meth {
                @meth.push: method (*@a) {
                    &meth(self, |@a);
                    .($meth-name, |@a) with self.renderer;
                    self.calls.push: ($meth-name => @a);
                };
                self.^add_method($meth-name, @meth[0]);
            }
        }
        @meth;
    }

    method FALLBACK(Str $op, |c) {
        self.can($op)
            ?? self."$op"(|c)
            !! die "unknown method: $op";
    }
}
