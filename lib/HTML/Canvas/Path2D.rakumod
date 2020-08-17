unit class HTML::Canvas::Path2D;

has Pair @.calls handles<Bool>;
has Bool $.closed;
method close {$!closed = True}
method flush {
    @!calls = ();
    $!closed = False;
}
