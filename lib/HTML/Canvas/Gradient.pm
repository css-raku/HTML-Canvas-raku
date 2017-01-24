use v6;

class HTML::Canvas::Gradient {

    use JSON::Fast;

    has Numeric $.x0;
    has Numeric $.y0;
    has Numeric $.x1;
    has Numeric $.y1;
    has Numeric $.r;
    method !type { with $!r { 'Radial' } else { 'Linear' } }

    my class ColorStop {
        use CSS::Declarations;
        use Color;
        has Numeric $.offset;
        has Color $!color;
        method color is rw { $!color }
        subset ColorOrStr where Color|Str;
        submethod TWEAK(ColorOrStr:D :$color!) {
            $!color = do given $color {
                when Str { self!css.color = $_; }
                default { $_ }
            }
        }
        method !css { state $css = CSS::Declarations.new; }
        method !css-writer { state $css-writer = (require CSS::Writer).new: :color-names }
        method !css-color-str(Color $_) {
            self!css-writer.write: |self!css.to-ast($_);
        }

        method to-js(Str $var) {
            '%s.addColorStop(%s, %s);'.sprintf($var, to-json($.offset), to-json( self!css-color-str($.color)))        }
    }
    has ColorStop @.colorStops;

    method addColorStop(Numeric $offset, Str $color) {
        @!colorStops.push: ColorStop.new( :$offset, :$color );
    }

    method to-js(Str $var, Str $ctx --> Array) {
        my @args = $!x0, $!y0, $!x1, $!y1;
        @args.push: $_ with $!r;
        my $args-js = @args.map({ to-json($_) }).join: ", ";
        my @js = 'var %s = %s.create%sGradient(%s);'.sprintf($var, $ctx, self!type, $args-js);
        @js.push: .to-js($var)
            for @!colorStops;
        @js;
    }
}
