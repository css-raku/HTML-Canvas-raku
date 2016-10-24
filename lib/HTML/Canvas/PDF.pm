use v6;
class HTML::Canvas::PDF {

    use PDF::Content;
    has PDF::Content $.gfx handles <content> is required;

    method renderer {
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

    proto method html2pdf(Str \op, *@args) {*};

    multi method html2pdf('rect', \x, \y, \w, \h) {
        warn "todo coordinate transforms + px to pt";
        $!gfx.Rectangle( x, y, w, h);
        $!gfx.CloseStroke;
    }

}
