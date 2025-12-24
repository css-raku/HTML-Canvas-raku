unit class HTML::Canvas::Gradient;

use JSON::Fast;

has Numeric $.x0;
has Numeric $.y0;
has Numeric $.x1;
has Numeric $.y1;
has Numeric $.r0;
has Numeric $.r1;
method type { with $!r0 // $!r1 { 'Radial' } else { 'Linear' } }

my class ColorStop {
    use CSS::Properties;
    use CSS::Properties::Util :&to-ast;
    use Color;
    has Numeric $.offset;
    has Color $!color;
    method color is rw { $!color }
    has CSS::Properties $!css;
    has $!css-writer;
    subset ColorOrStr where Color|Str;
    submethod TWEAK(ColorOrStr:D :$color!) {
        $!color = do given $color {
            when Str { self!css.color = $_; }
            default { $_ }
        }
    }
    method !css { $!css //= CSS::Properties.new; }
    method !css-writer { $!css-writer //= (require CSS::Writer).new: :color-names }
    method !css-color-str(Color $_) {
        self!css-writer.write: |to-ast($_);
    }

    method to-js(Str $var) {
        '%s.addColorStop(%s, %s);'.sprintf($var, to-json($.offset), to-json( self!css-color-str($.color)))        }
}
has ColorStop @.colorStops;

method addColorStop(Numeric $offset, Str $color) {
    @!colorStops.push: ColorStop.new( :$offset, :$color );
}

method to-js(Str $ctx, Str $var = 'grad' --> Array) {
    my @args = do with $!r0 // $!r1 {
        $!x0, $!y0, ($!r0 // 0), $!x1, $!y1, ($!r1 // 0);
    }
    else {
        $!x0, $!y0, $!x1, $!y1;
    }
    my $args-js = @args.map({ .&to-json }).join: ", ";
    my @js = 'var %s = %s.create%sGradient(%s);'.sprintf($var, $ctx, self.type, $args-js);
    @js.push: .to-js($var)
        for @!colorStops;
    @js;
}

