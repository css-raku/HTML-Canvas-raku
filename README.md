# perl6-HTML-Canvas

This a a lighweight module for composing HTML-5 canvases.

It supports the majority of the [HTML Canvas 2D Context](https://www.w3.org/TR/2dcontext/) API.

A canvas may be currently constructed via the API, then rendered to Javascript via the `.to-html` method.

```
use v6;
# Create a simple Canvas. Save as HTML

use HTML::Canvas;
my HTML::Canvas $canvas .= new;

$canvas.context: -> \ctx {
    ctx.save; {
        ctx.fillStyle = "orange";
        ctx.fillRect(10, 10, 50, 50);

        ctx.fillStyle = "rgba(0, 0, 200, 0.3)";
        ctx.fillRect(35, 35, 50, 50);
    }; ctx.restore;

    ctx.font = "18px Arial";
    ctx.fillText("Hello World", 40, 75);
}

# save canvas as PDF
my $html = "<html><body>{ $canvas.to-html( :width(250), :height(150) ) }</body></html>";
"t/canvas-demo.html".IO.spurt: $html;

## Images Patterns and Gradients
```
use HTML::Canvas;
use HTML::Canvas::Image;

my HTML::Canvas \ctx .= new;
my @html-body;

## Images ##

my \image = HTML::Canvas::Image.open("t/images/crosshair-100x100.jpg");
@html-body.push: HTML::Canvas.to-html: image, :style("visibility:hidden");

ctx.drawImage(image,  20,  10,  50, 50);
say ctx.js;

## Patterns ##

     my \pat = ctx.createPattern(image,'repeat');
     ctx.fillStyle=pat;
     ctx.translate(10,50);
     ctx.fillRect(10,10,150,100);

## Gradients

    with ctx.createRadialGradient(75,50,5,90,60,100) -> $grd {
        $grd.addColorStop(0,"red");
        $grd.addColorStop(0.5,"white");
        $grd.addColorStop(1,"blue");
        ctx.fillStyle = $grd;
        ctx.translate(10,200);
        ctx.fillRect(10, 10, 150, 100);
    }
```

# Methods

## Setters/Getters

### lineWidth

### lineDashOffset

### lineCap

### lineJoin

### font

### textBaseline

### textAlign

### direction

### fillStyle

### strokeStyle

### setLineDash/getLineDash/lineDash

## Graphics State

### save

### restore

### scale

### rotate

### translate

### transform

### setTransform

## Painting Methods

### clearRect

### fillRect

### strokeRect

### beginPath

### fill

### stroke

### clip

### fillText

### strokeText

### measureText

### drawImage

## Path Methods

### closePath

### moveTo

### lineTo

### quadraticCurveTo

### bezierCurveTo

### rect

### arc

## Gradients and Patterns

### createLinearGradient

### createRadialGradient

### createPattern


## See also

- Coming soon is [HTML::Canvas::To::PDF](https://github.com/p6-pdf/HTML-Canvas-To-PDF-p6) - a backend
for this module that renders to PDF, using the Perl 6 [PDF](https://github.com/p6-pdf) tool-chain.