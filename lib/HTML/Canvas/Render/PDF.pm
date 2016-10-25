use v6;
class HTML::Canvas::Render::PDF {

    use PDF::Content;
    has PDF::Content $.gfx handles <content> is required;
    has $.height is required; # height in points

    method callback {
        sub ($op, |c) {
            if $op eq 'scale'|'rotate'|'translate'|'transform'|'setTransform' {
                die "todo setTransform" if $op eq 'setTransform';
                self.transform($op,|c); 
            }
            else {
                self.html2pdf($op, |c);
            }
        }
    }

    method transform($op, *@args) {
        $!gfx.transform: |($op => @args);
    }

    constant Pt2Px = 0.75;       # 1px = 0.75 pt;
    sub pt(Numeric \l) { l * Pt2Px }
    method !pt-y(Numeric \l) { $!height - l * Pt2Px }

    proto method html2pdf(Str \op, *@args) {*};

    multi method html2pdf('rect', \x, \y, \w, \h) {
        $!gfx.Rectangle( pt(x), self!pt-y(y), pt(w), pt(h) );
        $!gfx.CloseStroke;
    }

}
