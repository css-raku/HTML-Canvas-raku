unit class HTML::Canvas::Image;

use HTML::Canvas::Graphic;
also does HTML::Canvas::Graphic;

use Base64::Native;
my subset DataURI of Str where /^('data:' [<t=.ident> '/' <s=.ident>]? $<b64>=";base64"? $<start>=",") /;
has DataURI $.data-uri;
my subset Source where Blob|Str|IO::Handle;
has Source:D $.source is required;
has Str $.image-type is required;

method !image-type($_, :$path!) {
    when m:i/^ jpe?g $/    { 'JPEG' }
    when m:i/^ gif $/      { 'GIF' }
    when m:i/^ png $/      { 'PNG' }
    when m:i/^ svg $/      { 'SVG' }
    when m:i/^ bmp $/      { 'BMP' }
    default {
        fail "unknown image type: $path";
    }
}

multi method open(DataURI $data-uri) {
    my $path = ~ $0;
    my Str \mime-type = ( $0<t> // '(missing)').lc;
    my Str \mime-subtype = ( $0<s> // '').lc;
    my Bool \base64 = ? $0<b64>;
    my Numeric \start = $0<start>.to;

    die "expected mime-type 'image/*', got '{mime-type}': $path"
        unless mime-type eq 'image';
    my $image-type = self!image-type(mime-subtype, :$path);
    self.new(:$image-type, :$data-uri);
}

multi method open(IO() $io-path) {
    self.open( $io-path.open( :r, :bin) );
}

multi method open(IO::Handle $source!) {
    my $path = $source.path;
    my Str $image-type = self!image-type($path.extension, :$path);
    self.new( :$source, :$image-type,);
}

method Str returns Str {
    given $!source {
        when Str  { .substr(0); }
        when Blob { .decode("latin-1"); }
        default   { .path.IO.slurp(:enc<latin-1>); }
    }
}

method Blob returns Blob {
    given $!source {
        when Blob { $_; }
        when Str  { .encode("latin-1"); }
        default   { .path.IO.slurp(:bin); }
    }
}

method data-uri is rw {
    Proxy.new(
        FETCH => sub ($) {
            $!data-uri //= do with $.Blob {
                my Str $enc = base64-encode($_, :str);
                'data:image/%s;base64,%s'.sprintf($.image-type.lc, $enc);
            }
            else {
                fail 'image is not associated with a source';
            }
        },
        STORE => sub ($, $!data-uri) {},
    )
}
