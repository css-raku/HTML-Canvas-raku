unit class HTML::Canvas::To::Cairo;

need Cairo;
use Color;
use CSS::Font;
use HTML::Canvas :FillRule;
use HTML::Canvas::Graphic;
use HTML::Canvas::Gradient;
use HTML::Canvas::Image;
use HTML::Canvas::ImageData;
use HTML::Canvas::Path2D;
use HTML::Canvas::Pattern;
use HarfBuzz::Buffer;
use HarfBuzz::Font::Cairo;
use HarfBuzz::Shaper::Cairo;
use HarfBuzz::Raw::Defs :hb-direction;
use Text::FriBidi::Defs :FriBidiPar;
use Text::FriBidi::Line;

has HTML::Canvas $.canvas is rw .= new;
has Cairo::Context $.ctx;

class Cache {
    has %.image;
    has %.gradient{HTML::Canvas::Gradient};
    has %.pattern{HTML::Canvas::Pattern};
    has HarfBuzz::Font::Cairo %.font;
}
class Font
    is CSS::Font {

    use Font::FreeType;
    use Font::FreeType::Face;
    use CSS::Font::Descriptor;
    use CSS::Font::Resources;
    use CSS::Font::Resources::Source;
    my constant Resources = CSS::Font::Resources;
    my constant Source = CSS::Font::Resources::Source;
    has Font::FreeType $!freetype .= new;
    has CSS::Font::Descriptor @.font-face;

    method cached-font(:$cache!) {
        my Source $source = Resources.source(:font(self), :@!font-face);
        my $key = do with $source { .Str } else { '' };

        $cache.font{$key} //= do {
            my Str $file = .IO.path with $source;
            $file ||= do {
                warn "falling back to mono-spaced font";
                %?RESOURCES<font/FreeMono.ttf>.absolute;
            }
            HarfBuzz::Font::Cairo.new: :$file;
        };
    }
}

has Font $!font .= new;
has Cache $.cache;
method current-font handles<ft-face cairo-font shaping-font> {
    $!font.cached-font(:$!cache);
}

submethod TWEAK(:$cache) is hidden-from-backtrace {
    with $cache {
        $!cache = $_;
    }
    else {
        $!cache .= new;
    }
    $!ctx //= Cairo::Context.new(self.surface);
    with $!canvas {
        $!font.font-face = .font-face;
        .callback.push: self.callback
    }
}

method surface handles<width height Blob> { $.canvas.surface }

method render(HTML::Canvas $canvas --> Cairo::Surface) {
    my $width = $canvas.width // 128;
    my $height = $canvas.height // 128;
    my $obj = self.new: :$width, :$height;
    $canvas.render($obj);
    $obj.surface;
}

method callback {
    sub (Str $op, |c) {
        with self.can: $op {
            .[0](self, |c);
        }
        else {
            warn "Canvas call not supported in Cairo: $op"
        }
    }
}

method _start {
    my $scale = 1.0 / $!canvas.adjusted-font-size(1.0);
    self.font;
    self.lineWidth($!canvas.lineWidth);
}
method _finish {
}

method save {
    $!ctx.save;
}
method restore {
    $!ctx.restore;
    self.font();
}
method !make-pattern(HTML::Canvas::Pattern $pattern) {
    $!cache.pattern{$pattern} //= do {
        my Bool \repeat-x = ? ($pattern.repetition eq 'repeat'|'repeat-x');
        my Bool \repeat-y = ? ($pattern.repetition eq 'repeat'|'repeat-y');
        my Bool \tiling = repeat-x || repeat-y;
        my $image = Cairo::Image.create(.Blob)
            with $pattern.image;
        if !tiling {
            # not tiling; simple image will suffice
            Cairo::Pattern::Surface.create($image.surface);
        }
        else {
            constant BigPad = 1000;
            my $width = $image.width;
            my $height = $image.height;
            my $padded-img = Cairo::Image.create(
                Cairo::FORMAT_ARGB32,
                $width + (repeat-x ?? 0 !! BigPad),
                $height + (repeat-y ?? 0 !! BigPad));
            my Cairo::Context $ctx .= new($padded-img);
            $ctx.set_source_surface($image);
            $ctx.paint;
            my Cairo::Pattern::Surface $patt .= create($padded-img.surface);
            $patt.extend = Cairo::Extend::EXTEND_REPEAT;
            $patt;
        }
    }
}
method !make-gradient(HTML::Canvas::Gradient $gradient --> Cairo::Pattern) {
    $!cache.gradient{$gradient} //= do {
        my @color-stops;
        for $gradient.colorStops.sort(*.offset) {
            my @rgb = (.r, .g, .b).map: (*/255)
                with .color;
            @color-stops.push: %( :offset(.offset), :@rgb );
        };
        @color-stops.push({ :rgb[1, 1, 1] })
            unless @color-stops;
        @color-stops[0]<offset> = 0.0;

        my $patt = do given $gradient.type {
            when 'Linear' {
              Cairo::Pattern::Gradient::Linear.create(.x0, .y0, .x1, .y1)
                  with $gradient;
            }
            when 'Radial' {
                Cairo::Pattern::Gradient::Radial.create(.x0, .y0, .r0, .x1, .y1, .r1)
                    with $gradient;
            }
        }
        $patt.add_color_stop_rgb(.<offset>, |.<rgb>)
            for @color-stops;
        $patt;
    }
}
method !make-color($_, $color) {
    when HTML::Canvas::Pattern:D {
        $!ctx.pattern: self!make-pattern($_);
    }
    when HTML::Canvas::Gradient:D {
        $!ctx.pattern: self!make-gradient($_);
    }
    default {
        my Numeric @rgba[4] = $color.rgba.map: ( */255 );
        @rgba[3] *= $!canvas.globalAlpha;
        $!ctx.rgba(|@rgba);
    }
}
method fillStyle($_) {
    self!make-color($_, $!canvas.css.background-color);
}
method strokeStyle($_) {
    self!make-color($_, $!canvas.css.color);
}
method scale(Numeric \x, Numeric \y) { $!ctx.scale(x, y); }
method rotate(Numeric \r) { $!ctx.rotate(r) }
method translate(Numeric \x, Numeric \y) { $!ctx.translate(x, y) }
method transform(Num() $xx, Num() $yx, Num() $xy, Num() $yy, Num() $x0, Num() $y0) {
    my Cairo::Matrix $matrix .= new.init: :$xx, :$yx, :$xy, :$yy, :$x0, :$y0;
    $!ctx.transform( $matrix );
}
method setTransform(Num() $xx, Num() $yx, Num() $xy, Num() $yy, Num() $x0, Num() $y0) {
    my Cairo::Matrix $matrix .= new.init: :$xx, :$yx, :$xy, :$yy, :$x0, :$y0;
    $!ctx.matrix = $matrix;
}
method rect(Numeric \x, Numeric \y, Numeric \w, Numeric \h ) {
    $!ctx.rectangle(x, y, w, h );
    $!ctx.close_path;
}
method fillRect(Numeric \x, Numeric \y, Numeric \w, Numeric \h ) {
    $!ctx.rectangle(x, y, w, h );
    $!ctx.fill;
}
method strokeRect(Numeric \x, Numeric \y, Numeric \w, Numeric \h ) {
    $!ctx.rectangle(x, y, w, h );
    $!ctx.stroke;
}
method clearRect(Numeric \x, Numeric \y, Numeric \w, Numeric \h) {
    # stub - should etch a clipping path. not paint a white rectangle
    $!ctx.save;
    $!ctx.rgb(1,1,1);
    self.fillRect(x, y, w, h);
    $!ctx.restore;
}

method !font-size { $!canvas.adjusted-font-size($!font.em) }
method font(Str $?) {
    $!font.css = $!canvas.css;
    $!ctx.set_font_size: self!font-size;
    $!ctx.set_font_face: $.cairo-font;
}
method !baseline-shift {
    my \t = $!ctx.text_extents("Q");

    given $!canvas.textBaseline {
        when 'alphabetic'  { 0 }
        when 'top'         { - t.y_bearing }
        when 'bottom'      { -(t.height + t.y_bearing) }
        when 'middle'      { -(t.height/2 + t.y_bearing) }
        when 'ideographic' { 0 }
        when 'hanging'     { - t.y_bearing }
        default            { 0 }
    }
}
method textBaseline($) { }
method !align(Numeric $advance-x) {
    my HTML::Canvas::Baseline $baseline = $!canvas.textBaseline;
    my $direction = $!canvas.direction;
    my HTML::Canvas::TextAlignment $align = do given $!canvas.textAlign {
        when 'start' { $direction eq 'ltr' ?? 'left' !! 'right' }
        when 'end'   { $direction eq 'rtl' ?? 'left' !! 'right' }
        default { $_ }
    }
    my $dx = $align eq 'left'
        ?? 0
        !! - $advance-x;
    $dx /= 2 if $align eq 'center';
    my $dy = self!baseline-shift;
    ($dx, $dy);
}
method textAlign($) { }
method direction(Str $_) {}
enum <x y>;
method fillText(Str $text, Numeric $x0, Numeric $y0, Numeric $maxWidth?) {
    my HarfBuzz::Shaper::Cairo $shaper = self!shaper: :$text;
    my @a := self!align($shaper.text-advance[x]);
    my $x = $x0 + @a[x];
    my $y = $y0 + @a[y];
    my Cairo::Glyphs $glyphs = $shaper.cairo-glyphs: :$x, :$y;
    $!ctx.show_glyphs($glyphs);
}
method strokeText(Str $text, Numeric $x0, Numeric $y0, Numeric $maxWidth?) {
    my HarfBuzz::Shaper::Cairo $shaper = self!shaper: :$text;
    my @a := self!align($shaper.text-advance[x]);
    $!ctx.save;
    $!ctx.new_path;
    my $x = $x0 + @a[x];
    my $y = $y0 + @a[y];
    my Cairo::Glyphs $glyphs = $shaper.cairo-glyphs: :$x, :$y;
    $!ctx.glyph_path($glyphs);
    $!ctx.stroke;
    $!ctx.restore;
}
multi method fill(FillRule $rule = 'nonzero') {

    temp $!ctx.fill_rule = $rule eq 'evenodd'
        ?? Cairo::FILL_RULE_EVEN_ODD
        !! Cairo::FILL_RULE_WINDING;

    $!ctx.fill;
}
multi method fill(HTML::Canvas::Path2D $path, FillRule $rule = 'nonzero') {
    $!ctx.new_path;
    self."{.key}"(|.value) for $path.calls();
    self.fill($rule);
}
method arc(Numeric \x, Numeric \y, Numeric \r,
           Numeric \startAngle, Numeric \endAngle, Bool $negative = False) {
    $!ctx.arc(:$negative, x, y, r, startAngle, endAngle);
}
method beginPath {
    $!ctx.new_path;
}
method closePath {
    $!ctx.close_path;
}
method lineWidth(Numeric $width) {
    $!ctx.line_width = $width;
}
method getLineDash() {}
method setLineDash(*@pattern) {
    $!ctx.set_dash(@pattern, +@pattern, $!canvas.lineDashOffset)
}
method !shaper(Str:D :$text!) {
    my UInt $direction = $!canvas.direction eq 'rtl'
        ?? FRIBIDI_PAR_RTL
        !! FRIBIDI_PAR_LTR;
    my Text::FriBidi::Line $line .= new: :$text, :$direction;
    my HarfBuzz::Buffer() $buf = %( :text($line.Str), :direction(HB_DIRECTION_LTR));
    given self.current-font {
        .shaping-font.size = self!font-size();
        .shaper($buf);
    }
}
method measureText(Str $text --> Numeric) {
    self!shaper(:$text).text-advance[0];
}
method moveTo(Numeric \x, Numeric \y) { $!ctx.move_to(x, y) }
method lineTo(Numeric \x, Numeric \y) { $!ctx.line_to(x, y) }
multi method stroke() {
    $!ctx.stroke
}
multi method stroke(HTML::Canvas::Path2D $path) {
    $!ctx.new_path;
    self."{.key}"(|.value) for $path.calls();
    self.stroke();
}

method lineCap(HTML::Canvas::LineCap $cap-name) {
    my $lc = %( :butt(Cairo::LineCap::LINE_CAP_BUTT),
                :round(Cairo::LineCap::LINE_CAP_ROUND),
                :square(Cairo::LineCap::LINE_CAP_SQUARE)){$cap-name};
    $!ctx.line_cap = $lc;
}
method lineJoin(HTML::Canvas::LineJoin $join-name) {
    my $lc = %( :miter(Cairo::LineJoin::LINE_JOIN_MITER),
                :round(Cairo::LineJoin::LINE_JOIN_ROUND),
                :bevel(Cairo::LineJoin::LINE_JOIN_BEVEL)){$join-name};
    $!ctx.line_join = $lc;
}
method clip() {
    $!ctx.clip;
}
method !canvas-to-surface(HTML::Canvas:D $sub-canvas, Numeric :$width!, Numeric :$height! ) {
    $!cache.image{$sub-canvas.html-id} //= do {
        my $renderer = self.new: :$width, :$height, :$!cache;
        $sub-canvas.render($renderer);
        $renderer.surface;
    }
}
method !to-surface(HTML::Canvas::Graphic:D $_,
                   :$width! is rw,
                   :$height! is rw --> Cairo::Surface) {
    my $k := .html-id;
    when HTML::Canvas {
        $width  = .html-width;
        $height = .html-height;
        $!cache.image{$k} //= self!canvas-to-surface($_, :$width, :$height);
    }
    when HTML::Canvas::ImageData {
        $width = .sw;
        $height = .sh;
        $!cache.image{$k} //= .image;
    }
    when .image-type eq 'PNG' {
        with ($!cache.image{$k} //= Cairo::Image.create(.Blob)) {
            $width = .width;
            $height = .height;
            $_
        }
    }
    default {
        # Something we can't handle; JPEG, GIF etc.
        # create place-holder
        my Cairo::Image $image = Cairo::Image.create(Cairo::FORMAT_ARGB32, $width // 10, $height // 10);
        my $ctx = Cairo::Context.new($image);
        $ctx.rgba(.9, .95, .95, .4);
        $ctx.paint;
        $image;
    }
}

multi method drawImage( HTML::Canvas::Graphic $obj,
                        Numeric \sx, Numeric \sy,
                        Numeric \sw, Numeric \sh,
                        Numeric \dx, Numeric \dy,
                        Numeric \dw, Numeric \dh) {
    unless sw =~= 0 || sh =~= 0 {
        $!ctx.save;
        # position at top right of visible area
        $!ctx.translate(dx, dy);
        # clip to visible area
        $!ctx.rectangle: 0, 0, dw, dh;
        $!ctx.close_path;
        $!ctx.clip;
        $!ctx.new_path;

        my \x-scale = dw / sw;
        my \y-scale = dh / sh;
        $!ctx.translate( -sx * x-scale, -sy * y-scale )
            if sx || sy;

        my Numeric $width = dw;
        my Numeric $height = dh;
        my Cairo::Surface $surface = self!to-surface($obj, :$width, :$height);

        $!ctx.scale(x-scale, y-scale);
        $!ctx.set_source_surface($surface);
        $!ctx.paint_with_alpha($!canvas.globalAlpha);
        $!ctx.restore;
    }
}
multi method drawImage(HTML::Canvas::Graphic $obj, Numeric $dx, Numeric $dy, Numeric $dw?, Numeric $dh?) {
    my Numeric $width = $dw;
    my Numeric $height = $dh;
    my Cairo::Surface $surface = self!to-surface($obj, :$width, :$height);

    $!ctx.save;
    $!ctx.translate($dx, $dy);
    my \x-scale = do with $dw { $_ / $width } else { 1.0 };
    my \y-scale = do with $dh { $_ / $height } else { 1.0 };
    $!ctx.scale(x-scale, y-scale);
    $!ctx.set_source_surface($surface);
    $!ctx.paint_with_alpha($!canvas.globalAlpha);

    $!ctx.restore;
}
method putImageData(HTML::Canvas::ImageData $image-data, Numeric $dx, Numeric $dy) {
    self.drawImage( $image-data, $dx, $dy)
}
method quadraticCurveTo(Numeric \cp1x, Numeric \cp1y, Numeric \x, Numeric \y) {
    my \cp2x = cp1x + 2/3 * (x - cp1x);
    my \cp2y = cp1y + 2/3 * (y - cp1y);
    $!ctx.curve_to( cp1x, cp1y, cp2x, cp2y, x, y);
}
method bezierCurveTo(Numeric \cp1x, Numeric \cp1y,
                     Numeric \cp2x, Numeric \cp2y,
                     Numeric \x,    Numeric \y) {
    $!ctx.curve_to( cp1x, cp1y, cp2x, cp2y, x, y);
}
method globalAlpha(Numeric) { }

method DESTROY {
    .destroy with $!ctx;
    $!ctx = Nil;
}

