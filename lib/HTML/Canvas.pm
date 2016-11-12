use v6;

class HTML::Canvas {
    use PDF::Content::Util::TransformMatrix;
    use CSS::Declarations;
    has Numeric @.transformMatrix is rw = [ 1, 0, 0, 1, 0, 0, ];
    has Pair @.calls;
    has Routine $.callback;

    has Str $.font = '10pt times-roman';
    method font is rw {
        Proxy.new(
            FETCH => sub ($) { $!font },
            STORE => sub ($, Str $!font) {
                $!css.font = $!font;
                .css = $!css with $!font-object;
                self!call('font', $!font);
            }
        );
    }

    has $.font-object is rw;
    has Str $.fillStyle is rw = 'black';
    method font-object is rw {
        Proxy.new(
            FETCH => sub ($) { $!font-object },
            STORE => sub ($, $!font-object) {
                .css = $!css with $!font-object;
            }
        )
    }
    method fillStyle is rw {
        Proxy.new(
            FETCH => sub ($) { $!fillStyle },
            STORE => sub ($, Str $!fillStyle) {
                $!css.color = $!fillStyle;
                self.calls.push: (:fillStyle[ $!fillStyle, ]);
                 .('fillStyle', $!css.color, :canvas(self)) with self.callback;
            }
        );
    }

    has CSS::Declarations $.css = CSS::Declarations.new( :color($!fillStyle), :$!font,  );
    has @!gsave;

    method TWEAK {
        .css = $!css with $!font-object;
    }

    method !transform(|c) {
        my @matrix = PDF::Content::Util::TransformMatrix::transform-matrix(|c);
        @!transformMatrix = PDF::Content::Util::TransformMatrix::multiply(@!transformMatrix, @matrix);
    }

    our %API is export(:API) = BEGIN %(
        :_start(method {} ),
        :_finish(method {
                        die "'save' unmatched by 'restore' at end of canvas context"
                            if @!gsave;
                    } ),
        :save(method {
                     my @ctm = @!transformMatrix;
                     @!gsave.push: {
                         :$!font,
                         :$!fillStyle,
                         :$!css,
                         :@ctm
                     };
                     $!css = $!css.new: :copy($!css);
                 } ),
        :restore(method {
                        if @!gsave {
                            my %state = @!gsave.pop;

                            @!transformMatrix = %state<ctm>.list;

                            $!font = %state<font>;
                            $!fillStyle = %state<fillStyle>;
                            $!css = %state<css>;
                            .css = $!css with $!font-object;
                        }
                        else {
                            warn "restore without preceding save";
                        }
                } ),
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
        :rect(method (Numeric $x, Numeric $y, Numeric $w, Numeric $h) { }),
        :strokeRect(method (Numeric $x, Numeric $y, Numeric $w, Numeric $h) { }),
        :fillRect(method (Numeric $x, Numeric $y, Numeric $w, Numeric $h) { }),
        :beginPath(method () {}),
        :fill(method () {}),
        :stroke(method () {}),
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
        :moveTo(method (Numeric \x, Numeric \y) {} ),
        :lineTo(method (Numeric \x, Numeric \y) {} ),
        :arc(method (Numeric $x, Numeric $y, Numeric $radius, Numeric $startAngle, Numeric $endAngle, Bool $counterClockwise?) { }),
    );

    method !call(Str $name, *@args) {
        self.calls.push: ($name => @args)
            unless $name eq '_start' | '_finish';
        .($name, |@args, :canvas(self)) with self.callback;
    }

    method context(&do-markup) {
        self._start;
        &do-markup(self);
        self._finish;
    }

    method js(Str :$context = 'ctx', :$sep = "\n") {
        use JSON::Fast;
        @!calls.map({
            my $name = .key;
            my @args = .value.map: { to-json($_) };
            my \fmt = $name eq 'font'|'fillStyle'
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
        $obj.context: {
            $obj."{.key}"(|.value)
                for @calls;
        }
    }

    method can(Str \name) {
        my @meth = callsame;
        if !@meth {
            with %API{name} -> &api {
                @meth.push: method (*@a) {
                    &api(self, |@a);
                    self!call(name, |@a);
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
