unit class HTML::Canvas::Path2D;

use JSON::Fast;

has Pair @.calls handles<Bool>;
has Bool $.closed;
has $.canvas;

method close {
    $!closed = True
}

method flush {
    @!calls = ();
    $!closed = False;
}

method clone(|c) {
    my @calls = @!calls.clone;
    nextwith(:@calls, |c);
}

method !call(Str $op, @args) {
    @!calls.push: $op => @args;
    .calls.push: $op => @args
        with $!canvas;
}

method moveTo(Numeric \x, Numeric \y) {
    self!call('moveTo', [x, y]);
}
method lineTo(Numeric \x, Numeric \y) {
    self!call('lineTo', [x, y]);
}
method quadraticCurveTo(Numeric \cx, Numeric \cy, Numeric \x, Numeric \y) {
    self!call('quadraticCurveTo', [cx, cy, x, y]);
}
method bezierCurveTo(Numeric \cx1, Numeric \cy1, Numeric \cx2, Numeric \cy2, Numeric \x, Numeric \y) {
    self!call('bezierCurveTo', [cx1, cy1, cx2, cy2, x, y]);
}
method rect(Numeric \x, Numeric \y, Numeric \w, Numeric \h) {
    self!call('rect', [x, y, w, h]);
}
method arc(Numeric \x, Numeric \y, Numeric \r, Numeric \startAngle, Numeric \endAngle, Bool \antiClockwise = False) {
    self!call('arc', [x, y, r, startAngle, endAngle, antiClockwise]);
}
method closePath {
    self!call('closePath', []);
}

method to-js(Str, Str $var = 'path' --> Array) {
    my @js = 'var %s = new Path2D();'.sprintf($var);
    for @!calls {
        my $meth = .key;
        my $args = .value.map({to-json($_)}).join: ', ';
        @js.push: '%s.%s(%s);'.sprintf($var, $meth, $args);
    }
    @js;
}
