use v6;
class HTML::Canvas::Render::PDF {

    use PDF::Content;
    has PDF::Content $.gfx handles <content> is required;
    has $.height is required; # height in points
    has $.font is required;

    method callback {
        sub ($op, |c) {
            if $op eq 'scale'|'rotate'|'translate'|'transform'|'setTransform' {
                die "todo setTransform" if $op eq 'setTransform';
                self.transform($op,|c); 
            }
            else {
                self.call2pdf($op, |c);
            }
        }
    }

    method transform($op, *@args) {
        $!gfx.transform: |($op => @args);
    }

    constant Pt2Px = 0.75;       # 1px = 0.75 pt;
    sub pt(Numeric \l) { l * Pt2Px }
    method !pt-y(Numeric \l) { $!height - l * Pt2Px }

    proto method call2pdf(Str \op, *@args) {*};
    multi method call2pdf('font', Str \expr) {
        with self.font {
            .parse: expr;
            $!gfx.font = [ .face, .em ];
        }
    }
    multi method call2pdf('rect', \x, \y, \w, \h) {
        $!gfx.Rectangle( pt(x), self!pt-y(y), pt(w), pt(h) );
    }
    multi method call2pdf('strokeRect', \x, \y, \w, \h) {
        $!gfx.Rectangle( pt(x), self!pt-y(y), pt(w), pt(h) );
        $!gfx.CloseStroke;
    }

    multi method call2pdf($op, *@args) is default {
        warn "unable to convert to PDF: {$op}({@args.join(", ")})"
    }

}
