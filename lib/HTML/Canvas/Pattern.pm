use v6;

class HTML::Canvas::Pattern {
    use JSON::Fast;
    subset Repetition of Str where 'repeat'|'repeat-x'|'repeat-y'|'no-repeat';
    has Repetition $.repetition = 'repeat';
    has $.image;

    method to-js(Str $var, Str $ctx --> Array) {
        my @js = 'var %s = %s.createPattern(%s, %s);'.sprintf($var, $ctx, $!image.js-ref, to-json($!repetition));
        @js;
    }
 }
