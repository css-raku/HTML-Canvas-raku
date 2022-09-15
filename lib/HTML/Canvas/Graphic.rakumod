unit role HTML::Canvas::Graphic;

has Numeric $.html-width is rw;
has Numeric $.html-height is rw;
has Str:D $.html-id = ~self.WHERE;
method js-ref {
    'document.getElementById("%s")'.sprintf($!html-id);
}
