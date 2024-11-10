use v6;
class HTML::Canvas::Pattern {
    use HTML::Canvas::Image;
    use JSON::Fast;
    subset Repetition of Str where 'repeat'|'repeat-x'|'repeat-y'|'no-repeat';
    has Repetition $.repetition = 'repeat';
    has HTML::Canvas::Image $.image;

    method to-js(Str $ctx, :$sym = my %{Any} --> Array) {
        my $image-js = $sym{$!image} // $!image.js-ref;
        my @js = '%s.createPattern(%s, %s)'.sprintf($ctx, $image-js, to-json($!repetition));
        @js;
    }
 }
