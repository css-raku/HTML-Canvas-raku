unit class HTML::Canvas::To::HTML;

use HTML::Canvas :LValue;
use HTML::Canvas::Gradient;
use HTML::Canvas::Path2D;
use HTML::Canvas::Pattern;

has HTML::Canvas $.canvas is rw .= new;
has %.var-num;
has %.sym{Any};

sub html-escape(Str $_) {
    .trans:
        /\&/ => '&amp;',
        /\</ => '&lt;',
        /\>/ => '&gt;',
        /\"/ => '&quot;',
}

#| lightweight html generation; canvas + javascript
multi method to-html(::?CLASS:D: *%opt) {
    temp %!sym = ();
    temp %!var-num = ();
    self.to-html($!canvas, |%opt);
}
multi method to-html(Any:D $obj, Numeric :$width = $obj.?width // Numeric, Numeric :$height = $obj.?height // Numeric, Str :$style='', *%opt) {
    $obj.html-width   = $_ with $width;
    $obj.html-height  = $_ with $height;

    if $obj.can('html') {
        $obj.html(:$style, |%opt);
    }
    elsif $obj.can('data-uri') {
        sprintf "<img id='%s' style='%s' src='%s' />\n".sprintf( $obj.html-id, html-escape($style), $obj.data-uri );
    }
    else {
        die "unable to convert this object to HTML";
    }
}

method html(Str :$style, Str :$sep = "\n    ", |c) is default {
    my $style-att  = do with $style { html-escape($_).fmt(' style="%s"') } else { '' };
    my $width-att  = do with $!canvas.html-width  { ' width="%dpt"'.sprintf($_) } else { '' };
    my $height-att = do with $!canvas.html-height { ' height="%dpt"'.sprintf($_) } else { '' };

    qq:to"END-HTML";
    <canvas{$width-att}{$height-att} id="{$!canvas.html-id}"{$style-att}></canvas>
    <script>
        var ctx = {$!canvas.js-ref}.getContext("2d");
        {self.js(:context<ctx>, :$sep, |c)}
    </script>
    END-HTML
}

method !var-ref($_, |c) {
    when Str|Numeric|Bool|List { }
    when HTML::Canvas::Gradient|HTML::Canvas::Path2D {
        %!sym{$_} //= self!declare-variable($_, |c);
    }
    when HTML::Canvas::Pattern {
        %!sym{$_} //= self!declare-variable($_, |c)
            for $_, .image;
    }
    default {
        %!sym{$_} //= self!declare-variable($_, |c)
            if .can('js-ref');
    }
}

method !declare-variable($obj, :$context!, :@js!) {
    my $var-name;

    my $type = do given $obj {
        when HTML::Canvas::Gradient  { 'grad_' }
        when HTML::Canvas::Pattern   { 'patt_' }
        when HTML::Canvas::Path2D    { 'path_' }
        when HTML::Canvas::ImageData { 'imgd_' }
        default { .can('js-ref') ?? 'node_' !!  Nil }
    }
    with $type {
        $var-name = $_ ~ ++%.var-num{$_};

        given $obj {
            when HTML::Canvas::Gradient|HTML::Canvas::Path2D {
                @js.append: .to-js($context, $var-name);
            }
            when HTML::Canvas::Pattern|HTML::Canvas::ImageData {
                @js.push: 'var %s = %s;'.sprintf($var-name, .to-js($context, :%!sym));
            }
            default {
                @js.push: 'var %s = %s;'.sprintf($var-name, .js-ref);
            }
        }
    }

    $var-name;
}

#| generate Javascript
method js(Str :$context = 'ctx', :$sep = "\n") {
    use JSON::Fast;
    my @js;

    # process statements (calls and assignments)
    for $!canvas.calls {
        my $name = .key;
        if $name eq 'var' {
            self!var-ref(.value, :$context, :@js);
        }
        else {
            my @args = .value.map: {
                when Str|Bool|Int { .&to-json }
                when Numeric  { .round(.0001).&to-json }
                when List { '[ ' ~ .map(&to-json).join(', ') ~ ' ]' }
                when %!sym{$_}:exists { %!sym{$_} }
                when HTML::Canvas::Pattern|HTML::Canvas::Gradient|HTML::Canvas::ImageData|HTML::Canvas::Path2D {
                    self!var-ref($_, :$context, :@js);
                    %!sym{$_} // .to-js($context, :%!sym);
                }
                default {
                    self!var-ref($_, :$context, :@js);
                    %!sym{$_} // .?js-ref // die "unexpected object: {.perl}";
                }
            }
        my \fmt = $name ~~ LValue
            ?? '%s.%s = %s;'
            !! '%s.%s(%s);';
        @js.push: fmt.sprintf( $context, $name, @args.join(", ") );
        }
    }

    @js.join: $sep;
}
