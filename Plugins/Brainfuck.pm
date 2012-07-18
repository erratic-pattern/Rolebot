package Rolebot::Plugins::Brainfuck;
use strict; use warnings;
use v5.10;
use Rolebot::Bot;

sub check_brackets {
    my $post = reverse @_;
    my $pre;
    my $bc = 0;
    my $i = 0;
    while (my $_ = chop $post) {
        $i++;
        $pre .= $_;
        $bc++ if $_ eq '[';
        $bc-- if $_ eq ']';
        return "Mismatched ] on column $i around: "
          . (substr $pre, -6, 6) . (substr reverse($post), 0, 6)
            if $bc < 0;
    }
    return undef;
}

sub interpret {
    my ($_) = @_;
    my (@stack, @tape);
    my $out = '';
    my $p = 0;
    $_ = reverse;
    my $start_time = time;
    my ($inp, $src) = /^(?:([^!]*)!)?(.*)$/;
    while ('' ne (my $c = chop $src)) {
        return "Time limit exceeded. Output: $out"
          if time - $start_time >= 12;
        return "Output limit exceeded. Output: $out"
          if length($out) > 200;
        given ($c) {
            when ('+') { ($tape[$p] += 1) %= 256;}
            when ('-') { ($tape[$p] -= 1) %= 256;}
            when ('>') { $p++; }
            when ('<') { $p-- if $p > 0; }
            when ('.') { $out .= chr $tape[$p]; }
            when (',') { $tape[$p] = ord (chop $inp);}
            when ('[') {
                ($src.'[') =~ /( \] (?: [^[\]]* | (?0) )* \[ )$/xp;
                if ($tape[$p]) {
                    push @stack, $src;
                }
                else {
                    $src = ${^PREMATCH};
                }
            }
            when (']') {
                if ($tape[$p]) {
                    $src = $stack[$#stack];
                }
                else {
                    pop @stack;
                }
            }
        }
    }
    return $out;
}


command bf => 'bf <program>[!<input>] -- execute a brainfuck program with optional input',
sub {
    my ($self, $args) = @_;
    my $src = $args->{body};
    my $err_msg = check_brackets $src;
    return (body => $err_msg) if defined $err_msg;
    return (body => interpret $src);
};

1;
