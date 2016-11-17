use v6;

class HTML::Canvas {
    use PDF::Content::Util::TransformMatrix;
    use CSS::Declarations;
    has Numeric @.transformMatrix is rw = [ 1, 0, 0, 1, 0, 0, ];
    has Pair @.subpath;
    has Str @!subpath-new;
    has Pair @.calls;
    has Routine @.callback;
    my subset LValue of Str where 'dashPattern'|'fillStyle'|'font'|'lineCap'|'lineJoin'|'lineWidth'|'strokeStyle';
    my subset PathOps of Str where 'moveTo'|'lineTo'|'quadraticCurveTo'|'bezierCurveTo'|'arcTo'|'arc'|'rect'|'closePath';

    has Numeric $.lineWidth = 1.0;
    method lineWidth is rw {
        Proxy.new(
            FETCH => sub ($) { $!lineWidth },
            STORE => sub ($, $!lineWidth) {
                self!call('lineWidth', $!lineWidth);
            }
        );
    }

    has Numeric @.dash-list;
    has Numeric $.lineDashOffset = 0.0;
    method lineDashOffset is rw {
        Proxy.new(
            FETCH => sub ($) { $!lineDashOffset },
            STORE => sub ($, $!lineDashOffset) {
                self!call('lineDashOffset', $!lineDashOffset);
            }
        );
    }
    my subset LineCap of Str where 'butt'|'round'|'square';
    has LineCap $.lineCap = 'butt';
    method lineCap is rw {
        Proxy.new(
            FETCH => sub ($) { $!lineCap },
            STORE => sub ($, $!lineCap) {
                self!call('lineCap', $!lineCap);
            }
        );
    }
    my subset LineJoin of Str where 'bevel'|'round'|'miter';
    has LineJoin $.lineJoin = 'bevel';
    method lineJoin is rw {
        Proxy.new(
            FETCH => sub ($) { $!lineJoin },
            STORE => sub ($, $!lineJoin) {
                self!call('lineJoin', $!lineJoin);
            }
        );
    }
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
    method font-object is rw {
        Proxy.new(
            FETCH => sub ($) { $!font-object },
            STORE => sub ($, $!font-object) {
                .css = $!css with $!font-object;
            }
        )
    }
    has Str $.fillStyle is rw = 'black';
    method fillStyle is rw {
        Proxy.new(
            FETCH => sub ($) { $!fillStyle },
            STORE => sub ($, Str $!fillStyle) {
                $!css.background-color = $!fillStyle;
                @!calls.push: (:fillStyle[ $!fillStyle, ]);
                .('fillStyle', $!css.background-color, :canvas(self)) for @!callback;
            }
        );
    }
    has Str $.strokeStyle is rw = 'black';
    method strokeStyle is rw {
        Proxy.new(
            FETCH => sub ($) { $!strokeStyle },
            STORE => sub ($, Str $!strokeStyle) {
                $!css.color = $!strokeStyle;
                @!calls.push: (:strokeStyle[ $!strokeStyle, ]);
                .('strokeStyle', $!css.color, :canvas(self)) for @!callback;
            }
        );
    }

    has CSS::Declarations $.css = CSS::Declarations.new( :background-color($!fillStyle), :color($!strokeStyle), :$!font,  );
    has @.gsave;

    method TWEAK {
        .css = $!css with $!font-object;
    }

    method !transform(|c) {
        my @matrix = PDF::Content::Util::TransformMatrix::transform-matrix(|c);
        @!transformMatrix = PDF::Content::Util::TransformMatrix::multiply(@!transformMatrix, @matrix);
    }

    our %API = BEGIN %(
        :_start(method {} ),
        :_finish(method {
                        warn "{@!subpath-new.join: ', '} not followed by fill() or stroke() at end of canvas context"
                            if @!subpath-new;
                        @!subpath = [];

                        die "'save' unmatched by 'restore' at end of canvas context"
                            if @!gsave;
                    } ),
        :save(method {
                     my @ctm = @!transformMatrix;
                     @!gsave.push: {
                         :$!font,
                         :$!fillStyle,
                         :$!strokeStyle,
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
                            $!strokeStyle = %state<strokeStyle>;
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
        :beginPath(method () { @!subpath = @!subpath-new = []; }),
        :fill(method () { self!draw-subpath() }),
        :stroke(method () { self!draw-subpath() }),
        :fillText(method (Str $text, Numeric $x, Numeric $y, Numeric $max-width?) { }),
        :strokeText(method (Str $text, Numeric $x, Numeric $y, Numeric $max-width?) { }),
        :measureText(method (Str $text, :$obj) {
                            with $!font-object {
                                my Numeric $width = .face.stringwidth($text, .em);
                                class { has Numeric $.width }.new: :$width
                            }
                            else {
                                fail "unable to measure text - not font object";
                            }
                        } ),
        :getLineDash(method () { @!dash-list } ),
        :moveTo(method (Numeric \x, Numeric \y) {} ),
        :lineTo(method (Numeric \x, Numeric \y) {} ),
        :quadraticCurveTo(method (Numeric \cp1x, Numeric \cp1y, Numeric \x, Numeric \y) {} ),
        :bezierCurveTo(method (Numeric \cp1x, Numeric \cp1y, Numeric \cp2x, Numeric \cp2y, Numeric \x, Numeric \y) {} ),
        :arc(method (Numeric $x, Numeric $y, Numeric $radius, Numeric $startAngle, Numeric $endAngle, Bool $counterClockwise?) { }),
        :closePath(method () {}),
    );

    # todo: slurping/itemization of @!dash-list?
    method setLineDash(@!dash-list) {
        self!call('setLineDash', @!dash-list.item);
    }
    method !call(Str $name, *@args) {
        @!calls.push: ($name => @args)
            unless $name eq '_start' | '_finish';

        if $name ~~ PathOps {
            #| draw later (via $.fill or $.stroke)
            @!subpath-new.push: $name;
            @!subpath.push: ($name => @args);
        }
        elsif $name eq 'fill'|'stroke' && ! @!subpath {
            warn "no current path to $name";
        }
        else {
            .($name, |@args, :canvas(self)) for @!callback;
        }
    }
    method !draw-subpath {
        @!subpath-new = [];
        for @!subpath -> \s {
            .(s.key, |s.value, :canvas(self)) for @!callback;
        }
    }

    method context(&do-markup) {
        self._start;
        &do-markup(self);
        self._finish;
    }

    #| generate Javascript
    method js(Str :$context = 'ctx', :$sep = "\n") {
        use JSON::Fast;
        @!calls.map({
            my $name = .key;
            my @args = .value.map: { to-json($_) };
            my \fmt = $name ~~ LValue
                ?? '%s.%s = %s;'
                !! '%s.%s(%s);';
            sprintf fmt, $context, $name, @args.join(", ");
        }).join: $sep;
    }

    #| lightweight html generation; canvas + javascript
    method html( Numeric :$width!, Numeric :$height!, Str :$style, Str :$id = ~ self.WHERE, :$sep = "\n    ", |c) {
        use HTML::Entity;
        my $Style = do with $style { ' style="%s"'.sprintf(encode-entities($_)) } else { '' };
        my $Js = self.js(:context<ctx>, :$sep, |c);
        my $Id = encode-entities($id);

        qq:to"END-HTML";
        <canvas width="{$width}pt" height="{$height}pt" id="$Id"$Style></canvas>
        <script>
            var ctx = document.getElementById("$Id").getContext("2d");
            $Js
        </script>
        END-HTML
    }

    #| rebuild the canvas, using the given renderer
    method render($renderer, :@calls = self.calls) {
        my @callback = [ $renderer.callback, ];
        my %opt = :font-object(.clone)
            with self.font-object;
        my $obj = self.new: :@callback, |%opt;
        $obj.context: {
            for @calls {
                with .key -> \call {
                    my \args = .value;
                    if call ~~ LValue {
                        +args
                            ?? ($obj."{call}"() = args[0])
                            !! $obj."{call}"();
                    }
                    else {
                        $obj."{call}"(|args);
                    }
                }
            }
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
            }
            self.^add_method(name, @meth[0]) if @meth;
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
