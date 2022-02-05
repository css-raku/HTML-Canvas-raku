unit role HTML::Canvas::Graphic;

has Numeric $.html-width is rw;
has Numeric $.html-height is rw;
has Str $!html-id;
method html-id {$!html-id //= ~self.WHERE}
method js-ref {
    'document.getElementById("%s")'.sprintf(self.html-id);
}
