class HTML::Canvas::ImageData {

    use HTML::Canvas::Graphic;
    also does HTML::Canvas::Graphic;

    use Cairo;
    use JSON::Fast;

    has Cairo::Image $.image;
    has Numeric ($.sx, $.sy, $.sw, $.sh);

    method to-js(Str $ctx, --> Array) {
        my @js = '%s.getImageData(%s, %s, %s, %s)'.sprintf($ctx, |($!sx, $!sy, $!sw, $!sh).map: { to-json($_) });
        @js;
    }
 }
