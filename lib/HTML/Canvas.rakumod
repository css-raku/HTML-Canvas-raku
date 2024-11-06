unit class HTML::Canvas:ver<0.1.2>;

use Hash::Agnostic;
use HTML::Canvas::Graphic;

also does HTML::Canvas::Graphic;
also does Hash::Agnostic;

need Cairo;
use CSS::Properties;
use CSS::Font::Descriptor;
use HTML::Canvas::Gradient;
use HTML::Canvas::Image;
use HTML::Canvas::ImageData;
use HTML::Canvas::Path2D;
use HTML::Canvas::Pattern;
has Numeric $.width = 612;
has Numeric $.height = 792;
has Pair @.calls;
has Routine @.callback;
has $!feed where .isa('HTML::Canvas::To::Cairo');
has $!html handles <html js>;
has CSS::Font::Descriptor @.font-face;
has Cairo::Surface $.surface = Cairo::Image.create(Cairo::FORMAT_ARGB32, $!width, $!height);
submethod TWEAK(::?CLASS:D $canvas: :$cache) {
    # setup our cairo and html feeds
    $!html = (require ::('HTML::Canvas::To::HTML')).new: :$canvas;
    my %o;
    %o<cache> = $_ with $cache;
    my $class = (require ::('HTML::Canvas::To::Cairo'));
    $!feed = $class.new: :$canvas, |%o;
}

multi method to-html(::?CLASS:D: |c) { $!html.to-html: |c }
multi method to-html(::?CLASS:U: |c) is DEPRECATED("HTML::Canvas:D.to-html()") { self.new.to-html: |c }

# -- Graphics Variables --
my Attribute %GraphicVars;
multi trait_mod:<is>(Attribute $att, :$graphics!) {
    my $name = $att.name.substr(2);
    %GraphicVars{$name} = $att;
}

my %API;
multi trait_mod:<is>(Method $m, :$api!) {
    my \name = $m.name;

    $m.wrap: method (*@a) is hidden-from-backtrace {
        my \rv = callsame();
        self!call(name, |@a);
        rv;
    }

   %API{name} = True
        unless name ~~ '_start'|'_finish';
}
constant @PathAPI = <moveTo lineTo quadraticCurveTo bezierCurveTo arcTo arc rect closePath>;
has HTML::Canvas::Path2D $.path is graphics handles(@PathAPI) .= new: :canvas(self);
method subpath is DEPRECATED<path> { $!path.calls }

method image { $!surface }
subset LValue of Str is export(:LValue) where 'dashPattern'|'fillStyle'|'font'|'lineCap'|'lineJoin'|'lineWidth'|'strokeStyle'|'textAlign'|'textBaseline'|'direction'|'globalAlpha';
my subset FillRule is export(:FillRule) of Str where 'nonzero'|'evenodd';

has Numeric @.transformMatrix is rw is graphics = [ 1, 0, 0, 1, 0, 0, ];
has Numeric $.lineWidth is graphics = 1.0;
method lineWidth is rw {
    Proxy.new(
        FETCH => sub ($) { $!lineWidth },
        STORE => sub ($, $!lineWidth) {
            self!call('lineWidth', $!lineWidth);
        }
    );
}

has Numeric $.globalAlpha is graphics = 1.0;
method globalAlpha is rw {
    Proxy.new(
        FETCH => sub ($) { $!globalAlpha },
        STORE => sub ($, $!globalAlpha) {
            self!call('globalAlpha', $!globalAlpha);
        }
    );
}

has Numeric @.lineDash is graphics;
method lineDash is rw {
    Proxy.new(
        FETCH => sub ($) { @!lineDash },
        STORE => sub ($, \l) { self.setLineDash(l) },
        )
}
has Numeric $.lineDashOffset is graphics = 0.0;
method lineDashOffset is rw {
    Proxy.new(
        FETCH => sub ($) { $!lineDashOffset },
        STORE => sub ($, $!lineDashOffset) {
            self!call('lineDashOffset', $!lineDashOffset);
        }
    );
}
subset LineCap of Str where 'butt'|'round'|'square';
has LineCap $.lineCap is graphics = 'butt';
method lineCap is rw {
    Proxy.new(
        FETCH => sub ($) { $!lineCap },
        STORE => sub ($, $!lineCap) {
            self!call('lineCap', $!lineCap);
        }
    );
}
subset LineJoin of Str where 'bevel'|'round'|'miter';
has LineJoin $.lineJoin is graphics = 'bevel';
method lineJoin is rw {
    Proxy.new(
        FETCH => sub ($) { $!lineJoin },
        STORE => sub ($, $!lineJoin) {
            self!call('lineJoin', $!lineJoin);
        }
    );
}
has Str $.font is graphics = '10pt times-roman';
method font is rw {
    Proxy.new(
        FETCH => sub ($) { $!font },
        STORE => sub ($, Str $!font) {
            $!css.font = $!font;
            self!call('font', $!font);
        }
    );
}
#| browsers seem to be display fonts at 4/3 of actual size. Not sure
#| if this should be treated as UI dependant.
method adjusted-font-size(Numeric $raw-size) {
    $raw-size * 4/3;
}

subset Baseline of Str where 'alphabetic'|'top'|'hanging'|'middle'|'ideographic'|'bottom';
has Baseline $.textBaseline is graphics = 'alphabetic';
method textBaseline is rw {
    Proxy.new(
        FETCH => sub ($) { $!textBaseline },
        STORE => sub ($, Str $!textBaseline) {
            self!call('textBaseline', $!textBaseline);
        }
    );
}

subset TextAlignment of Str where 'start'|'end'|'left'|'right'|'center';
has TextAlignment $.textAlign is graphics = 'start';
method textAlign is rw {
    Proxy.new(
        FETCH => sub ($) { $!textAlign },
        STORE => sub ($, Str $!textAlign) {
            self!call('textAlign', $!textAlign);
        }
    );
}

subset TextDirection of Str where 'ltr'|'rtl';
has TextDirection $.direction is graphics = 'ltr';
method direction is rw {
    Proxy.new(
        FETCH => sub ($) { $!direction },
        STORE => sub ($, Str $!direction) {
            self!call('direction', $!direction);
        }
    );
}

subset ColorSpec where Str|HTML::Canvas::Gradient|HTML::Canvas::Pattern;
has ColorSpec $.fillStyle is graphics = 'black';
method fillStyle is rw {
    Proxy.new(
        FETCH => sub ($) { $!fillStyle },
        STORE => sub ($, ColorSpec $!fillStyle) {
            $!css.background-color = $!fillStyle
                if $!fillStyle ~~ Str;
            @!calls.push('fillStyle' => [$!fillStyle]);
        }
    );
}
has ColorSpec $.strokeStyle is graphics = 'black';
method strokeStyle is rw {
    Proxy.new(
        FETCH => sub ($) { $!strokeStyle },
        STORE => sub ($, ColorSpec $!strokeStyle) {
            $!css.color = $!strokeStyle
                if $!strokeStyle ~~ Str;
            @!calls.push('strokeStyle' => [$!strokeStyle]);
        }
    );
}

has CSS::Properties $.css is graphics .= new( :background-color($!fillStyle), :color($!strokeStyle), :$!font,  );
has @.gsave;

method _start() is api {}
method _finish is api {
    warn "{$!path.calls.map(*.key).join: ', '} not closed by fill() or stroke() at end of canvas context"
        if $!path && !$!path.closed;
    $!path.flush;

    die "'save' unmatched by 'restore' at end of canvas context"
        if @!gsave;
}
method save is api {
      my %gstate = %GraphicVars.pairs.map: {
          my Str $key       = .key;
          my Attribute $att = .value;
          my $val           = $att.get_value(self);
          $val .= clone unless $val ~~ Str|Numeric;
          $key => $val;
      }

      @!gsave.push: %gstate;
      $!css = $!css.new: :copy($!css);
}
method restore is api {
    if @!gsave {
          my %gstate = @!gsave.pop;

          for %gstate.pairs {
              my Str $key       = .key;
              my Attribute $att = %GraphicVars{$key};
              my $val           = .value;
              $att.set_value(self, $val ~~ Array ?? @$val !! $val);
          }
          $!css.font = $!font;
      }
      else {
          warn "restore without preceding save";
      }
}
method scale(Numeric $x, Numeric $y) is api {
    given @!transformMatrix {
        $_ *= $x for .[0], .[1];
        $_ *= $y for .[2], .[3];
    }
}
method rotate(Numeric $rad) is api {
    my \c = cos($rad);
    my \s = sin($rad);
    given @!transformMatrix {
        .[0..3] = [
            .[0] * +c + .[2] * s,
            .[1] * +c + .[3] * s,
            .[0] * -s + .[2] * c,
            .[1] * -s + .[3] * c,
        ]

    }
}
method translate(Numeric \x, Numeric \y) is api {
    given @!transformMatrix {
        .[4] += .[0] * x + .[2] * y;
        .[5] += .[1] * x + .[3] * y;
    }
}
method transform(Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) is api {
    @!transformMatrix = do given @!transformMatrix {
        [
            .[0] * a + .[2] * b,
            .[1] * a + .[3] * b,

            .[0] * c + .[2] * d,
            .[1] * c + .[3] * d,

            .[0] * e + .[2] * f + .[4],
            .[1] * e + .[3] * f + .[5],
        ];
    }
}
method setTransform(Numeric \a, Numeric \b, Numeric \c, Numeric \d, Numeric \e, Numeric \f) is api {
    @!transformMatrix = [a, b, c, d, e, f];
}
method clearRect(Numeric $x, Numeric $y, Numeric $w, Numeric $h) is api { }
method fillRect(Numeric $x, Numeric $y, Numeric $w, Numeric $h) is api {
    self!setup-fill();
}
method strokeRect(Numeric $x, Numeric $y, Numeric $w, Numeric $h) is api {
    self!setup-stroke();
}
method beginPath is api { $!path.flush }
proto method fill($?, $?) is api {*}
multi method fill(FillRule $ = 'nonzero') {
    self!setup-fill();
    self!draw-subpath()
}
multi method fill(HTML::Canvas::Path2D $, FillRule $ = 'nonzero') {
    self!setup-fill();
}
proto method stroke($?) is api {*}
multi method stroke {
    self!setup-stroke();
    self!draw-subpath()
}
multi method stroke(HTML::Canvas::Path2D $) {
    self!setup-stroke();
}
method clip is api {
    self!draw-subpath();
}
method fillText(Str $text, Numeric $x, Numeric $y, Numeric $max-width?) is api {
    self!setup-fill();
}
method strokeText(Str $text, Numeric $x, Numeric $y, Numeric $max-width?) is api {
    self!setup-stroke();
}
method drawImage(HTML::Canvas::Graphic \image, Numeric \dx, Numeric \dy, *@args) is api {
}
method putImageData(HTML::Canvas::ImageData \image-data, Numeric \dx, Numeric \dy, *@args) is api {
}
method setLineDash(@!lineDash) is api {
}
method getLineDash is api { @!lineDash }

#| non-api method to serialize canvas
method toDataURL($fmt?, Numeric $res?) {
    with $fmt {
        fail "can only handle PNG format"
            unless .lc.contains('png');
    }
    warn "ignoring resolution: $_" with $res;

    my Blob $source = $!feed.Blob;
    my HTML::Canvas::Image $image .= new: :image-type<PNG>, :$source;
    $image.data-uri;
}

method createLinearGradient(Numeric $x0, Numeric $y0, Numeric $x1, Numeric $y1) {
    self!var: HTML::Canvas::Gradient.new: :$x0, :$y0, :$x1, :$y1;
}
method createRadialGradient(Numeric $x0, Numeric $y0, Numeric $r0, Numeric $x1, Numeric $y1, Numeric:D $r1) {
    self!var: HTML::Canvas::Gradient.new: :$x0, :$y0, :$r0, :$x1, :$y1, :$r1;
}
method createPattern(HTML::Canvas::Image $image, HTML::Canvas::Pattern::Repetition $repetition = 'repeat') {
    self!var: HTML::Canvas::Pattern.new: :$image, :$repetition;
}
method getImageData(Numeric $sx, Numeric $sy, Numeric $sw, Numeric $sh) {
    use Cairo;
    my Cairo::Image $image = Cairo::Image.create(Cairo::FORMAT_ARGB32, $sw, $sh);
    my $ctx = Cairo::Context.new($image);
    $ctx.rgb(1.0, 1.0, 1.0);
    $ctx.paint;
    $ctx.set_source_surface($!surface, -$sx, -$sy);
    $ctx.rectangle($sx, $sy, $sh, $sh);
    $ctx.paint;
    self!var: HTML::Canvas::ImageData.new: :$image, :$sx, :$sy, :$sw, :$sh;
}
method measureText(Str $text) {
    my @measures = @!callback.map({.('measureText', $text) || Empty});
    if @measures {
        given @measures.sum / +@measures -> $width {
            my class TextMetrics { has Numeric $.width }.new: :$width
        }
    }
}
method !var($var) {
    @!calls.push: (:$var);
    $var;
}
method !call(Str $name, *@args) {
    @!calls.push: ($name => @args)
        unless $name ~~ '_start'|'_finish';

    if $name ~~ 'fill'|'stroke' && ! (@args[0] ~~ HTML::Canvas::Path2D ?? @args[0] !! $!path) {
        warn "no current path to $name";
    }
    else {
        .($name, |@args) for @!callback;
    }
}
method !setup-fill { .('fillStyle', $!fillStyle) for @!callback; }
method !setup-stroke { .('strokeStyle', $!strokeStyle) for @!callback; }

method !draw-subpath {
    for $!path.calls -> \s {
        .(s.key, |s.value) for @!callback;
    }
    $!path.close();
}

method context(&actions) {
    self._start;
    self.&actions();
    self._finish;
}


#| rebuild the canvas, using the given renderer
method render($renderer, :@calls = self.calls) {
    my @callback = [ $renderer.callback, ];
    my $canvas = self.new: :@callback;
    temp $renderer.canvas = $canvas;
    $canvas.context: {
        for @calls {
            given .key -> \call {
                my \args = .value;
                if +args && call ~~ LValue {
                    $canvas."{call}"() = args[0];
                }
                else {
                    $canvas."{call}"(|args);
                }
            }
        }
    }
}

# approximate JS associative access to attributes / methods
# ctx["fill"]()
# ctx["strokeStyle"] = "rgb(100, 200, 100)";
# console.log(ctx["strokeStyle"])

#++ Hash::Agnostic interface
method new(|c) { self.bless: |c; }
method keys { (%API.keys.Slip, %GraphicVars.keys.Slip, @PathAPI.Slip).sort }
multi method AT-KEY(LValue:D $_) is rw { self.can($_)[0](self) }
multi method AT-KEY(Str:D $_) is rw {
    with self.can($_) {
        my &meth := .[0];
        my &curried;
        Proxy.new:
          FETCH => -> $ { &curried //= -> |c { &meth(self, |c); } },
          STORE => -> $, $val { &meth(self) = $val; }
    }
    else {
        die X::Method::NotFound.new( :method($_), :typename(self.^name) )
    }
}

