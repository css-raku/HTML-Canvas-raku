use v6;
use CSS::Declarations::Font;
class HTML::Canvas::To::Cairo::Font
    is CSS::Declarations::Font {

    use Cairo;
    has Cairo::Context $!ctx;
    has Numeric $.scale = 1.0;

    method TWEAK( :$!ctx! ) { }

    method stringwidth($text, Numeric $) {
        $!ctx.text_extents($text).width * $!scale;
    }

    method weight returns Cairo::FontWeight {
        callsame() >= 700
            ?? (Cairo::FontWeight::FONT_WEIGHT_BOLD)
            !! (Cairo::FontWeight::FONT_WEIGHT_NORMAL);
    }

    method slant returns Cairo::FontSlant {
        given $.style {
            when 'italic'  { Cairo::FontSlant::FONT_SLANT_ITALIC }
            when 'oblique' { Cairo::FontSlant::FONT_SLANT_OBLIQUE }
            default        { Cairo::FontSlant::FONT_SLANT_NORMAL }
        }
    }
}

