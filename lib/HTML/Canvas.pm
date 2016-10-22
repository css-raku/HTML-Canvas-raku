use v6;
use PDF::Content::Ops :OpCode;
use PDF::Content::Util::TransformMatrix;

class HTML::Canvas {
    has Numeric @.TransformationMatrix is rw = [ 1, 0, 0, 1, 0, 0, ];
    has @.calls;
    has Routine &.callback;

    method !transform(|c) {
        my @matrix = PDF::Content::Util::TransformMatrix::transform-matrix(|c);
        @!TransformationMatrix = PDF::Content::Util::TransformMatrix::multiply(@!TransformationMatrix, @matrix);
    }

    has Method %API = BEGIN %(
        :scale(method (Numeric $x, Numeric $y) {
                      self!transform: :scale[$x, $y];
                  }),
        :rotate(method (Numeric $angle) {
                      self!transform: :rotate($angle);
                  }),
        :translate(method (Numeric $angle) {
                      self!transform: :translate($angle);
                  }),
        :transform(method (Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
                      @!TransformationMatrix = PDF::Content::Util::TransformMatrix::multiply(@!TransformationMatrix, [a, b, c, d, e, f]);
                      }),
        :setTransform(method (Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
                          my @identity = PDF::Content::Util::TransformMatrix::identity;
                          @!TransformationMatrix = PDF::Content::Util::TransformMatrix::multiply(@identity, [a, b, c, d, e, f]);
                      }),
        :arc(method (Numeric $x, Numeric $y, Numeric $radius, Numeric $startAngle, Numeric $endAngle, Bool $counterClockwise?) { }),
        :beginPath(method () {}),
        :rect(method (Numeric $x, Numeric $y, Numeric $w, Numeric $h) { }),
        :fillText(method (Str $text, Numeric $x, Numeric $y, Numeric $max-width?) { }),
        :stroke(method () {}),
    );

    method to-pdf(\gfx) {
        # stub
        [
         OpCode::SetStrokeRGB => [1.0, 0.5, 0.3],
         OpCode::Rectangle => [10, 10, 100, 50],
         OpCode::Stroke,
        ]
    }

    method can(Str \name) {
        my @meth = callsame;
        if !@meth {
            with %API{name} -> &meth {
                @meth.push: method (*@a) {
                    &meth(self, |@a);
                    self.calls.push: ((name) => @a);
                    .(name, |@a, :obj(self)) with self.callback;
                };
                self.^add_method(name, @meth[0]);
            }
        }
        @meth;
    }
    method dispatch:<.?>(\name, |c) is raw {
        self.can(name) ?? self."{name}"(|c) !! Nil
    }
    method FALLBACK(Str \name, |c) {
        self.can(name)
            ?? self."{name}"(|c)
            !! die die X::Method::NotFound.new( :method(name), :typename(self.^name) );
    }
}
