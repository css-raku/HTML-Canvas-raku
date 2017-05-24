use v6;

class HTML::Canvas::Tracer {

    has UInt $!indent = 0;

    submethod TWEAK(:$canvas!) {
        with $canvas {
            .callback.push: sub  ($op, |c) { self."{$op}"(|c); }
        }
    }

    method FALLBACK($name, *@args, *%opts) {
	$!indent = 0 if $name eq '_start'|'_finish';
	$!indent-- if $name eq 'restore' && $!indent;
	$*ERR.print(('  ' x $!indent) ~ $name ~ '(');
	$*ERR.print(.perl ~ ', ') for @args;
	$*ERR.printf(':%s(%s), ', .key, .value.gist) for %opts.pairs.sort;
	$*ERR.say(');');
	$!indent++ if $name eq 'save';
    }

}
