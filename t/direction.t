use Test;
plan 1;

use HTML::Canvas;
use HTML::Canvas::To::Cairo;
use HTML::Canvas::To::HTML;
use Cairo;

constant $LRM = "\c[LEFT-TO-RIGHT MARK]";
constant $LRO = "\c[LEFT-TO-RIGHT OVERRIDE]";
constant $RLO = "\c[RIGHT-TO-LEFT OVERRIDE]";
constant $PDF = "\c[POP DIRECTIONAL FORMATTING]";

my HTML::Canvas $canvas .= new: :width(150), :height(100);
my HTML::Canvas::To::Cairo $feed .= new: :width(650), :height(400), :$canvas;
$canvas.context: {
    # example adapted from from https://stackoverflow.com/questions/8961636/html5-canvas-filltext-with-right-to-left-string/15979861#15979861
    .textAlign = 'right';
    .direction = 'rtl';
    .font = "22px Unifont";
    # Simple Sentence with punctuation.
    my \str1 = "این یک آزمایش است.";
    # Few sentences with punctuation and numerals. 
    my \str2 = "۱ آزمایش. 2 آزمایش، سه آزمایش & Foo آزمایش!";
    # Needs implicit bidi marks to display correctly.
    my \str3 = "آزمایش برای Foo Ltd. و Bar Inc. باشد که آزموده شود.";
    # Implicit bidi marks added; "Foo Ltd.&lrm; و Bar Inc.&lrm;"
    my \str4 = "آزمایش برای Foo Ltd.{$LRM} و Bar Inc.{$LRM} باشد که آزموده شود.";

    .fillText(str1, 620, 60);
    .fillText(str2, 620, 100);
    .fillText(str3, 620, 140);
    .fillText(str4, 620, 180);
    .fillText("rtl (with) parens", 620, 220);
    # left to right as dominant direction
    .direction = 'ltr';
    .fillText("Left {$RLO}Right{$PDF} left", 620, 260);

    # add a guide line
    .strokeStyle = "rgba(255, 50, 50, 0.6)";
    .lineWidth = 4.0;
    .moveTo(620, 50);
    .lineTo(620,260);
    .stroke;
}

# save canvas as PNG
my Cairo::Surface $surface = $feed.surface;
$surface.finish;

# also save comparative HTML

my $width = $feed.width;
my $height = $feed.height;
"t/direction.html".IO.spurt: HTML::Canvas::To::HTML.new(:$canvas).html;

pass();
done-testing();
