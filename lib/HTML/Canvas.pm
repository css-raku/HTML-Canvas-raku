use v6;
use PDF::Content::Util::TransformMatrix;

class HTML::Canvas {
    has Numeric @.transformMatrix is rw = [ 1, 0, 0, 1, 0, 0, ];
    has Pair @.calls;
    has Routine $.callback;
    has $.font-object is rw;
    has $!font-style = '10pt times-roman';

    method !transform(|c) {
        my @matrix = PDF::Content::Util::TransformMatrix::transform-matrix(|c);
        @!transformMatrix = PDF::Content::Util::TransformMatrix::multiply(@!transformMatrix, @matrix);
    }

    our %API is export(:API) = BEGIN %(
        :_start(method {} ),
        :_finish(method {} ),
        :scale(method (Numeric $x, Numeric $y) {
                      self!transform: :scale[$x, $y];
                  }),
        :rotate(method (Numeric $angle) {
                      self!transform: :rotate($angle);
                  }),
        :translate(method (Numeric $tx, Numeric $ty) {
                      self!transform: :translate[$tx, $ty];
                  }),
        :transform(method (Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
                      @!transformMatrix = PDF::Content::Util::TransformMatrix::multiply(@!transformMatrix, [a, b, c, d, e, f]);
                      }),
        :setTransform(method (Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) {
                             @!transformMatrix = [a, b, c, d, e, f];
                      }),
        :arc(method (Numeric $x, Numeric $y, Numeric $radius, Numeric $startAngle, Numeric $endAngle, Bool $counterClockwise?) { }),
        :beginPath(method () {}),
        :rect(method (Numeric $x, Numeric $y, Numeric $w, Numeric $h) { }),
        :strokeRect(method (Numeric $x, Numeric $y, Numeric $w, Numeric $h) { }),
        :fillText(method (Str $text, Numeric $x, Numeric $y, Numeric $max-width?) { }),
        :measureText(method (Str $text, :$obj) {
                            with $!font-object {
                                my Numeric $width = .face.stringwidth($text, .em);
                                class { has Numeric $.width }.new: :$width
                            }
                            else {
                                fail "unable to measure text - not font object";
                            }
                        } ),
        :stroke(method () {}),
    );

    method !add-call(Str $name, *@args) {
        self.calls.push: ($name => @args);
        .($name, |@args, :canvas(self)) with self.callback;
    }

    method font is rw {
        Proxy.new(
            FETCH => sub ($) { $!font-style },
            STORE => sub ($, Str $!font-style) {
                self!add-call('font', $!font-style);
            }
        );
    }

    method context(&do-stuff) {
        self._start;
        &do-stuff(self);
        self._finish;
    }

    method js(Str :$context = 'ctx', :$sep = "\n") {
        use JSON::Fast;
        @!calls.grep(*.key ne '_start'|'_finish').map({
            my $name = .key;
            my @args = .value.map: { to-json($_) };
            my \fmt = $name eq 'font'
                ?? '%s.%s = %s;'
                !! '%s.%s(%s);';
            sprintf fmt, $context, $name, @args.join(", ");
        }).join: $sep;
    }

    method html( Numeric :$width!, Numeric :$height!, Str :$style, Str :$id = ~ self.WHERE) {
        use HTML::Entity;
        my $Style = do with $style { ' style="%s"'.sprintf(encode-entities($style)) } else { '' };
        my $Js = self.js(:context<ctx>, :sep("\n    "));
        my $Id = encode-entities($id);

        qq:to"END-HTML";
        <canvas width="{$width}pt" height="{$height}pt" id="$Id"$Style></canvas>
        <script>
            var ctx = document.getElementById("$Id").getContext("2d");
            $Js
        </script>
        END-HTML
    }

    method render($renderer, :@calls = self.calls) {
        my $callback = $renderer.callback;
        my $obj = self.new: :$callback;
        $obj._start;
        $obj."{.key}"(|.value)
            for @calls;
        $obj._finish;
    }

    method can(Str \name) {
        my @meth = callsame;
        if !@meth {
            with %API{name} -> &meth {
                @meth.push: method (*@a) {
                    &meth(self, |@a);
                    self!add-call(name, |@a);
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
