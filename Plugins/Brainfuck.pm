package Rolebot::Plugins::Brainfuck;
use strict; use warnings;
use v5.10;
use Rolebot::Bot;

sub check_brackets {
    my ($post) = @_;
    my ($pre, $bc, $i);
    while (my $_ = chop $post) {
        $i++;
        $pre .= $_;
        $bc++ if $_ eq '[';
        $bc-- if $_ eq ']';
        return "Mismatched ] on column $i around: "
          . substr $pre, -1, 4 . substr $post, 0, 4
            if $bc < 0;
    }
    return undef;
}

sub interpret {
    my ($_) = @_;
    my ($out, $p, @stack, @tape);
    $_ = reverse;
    my ($src, $inp) = /^([^!]*)!(.*)$/;
    while (defined (my $c = chop $src)) {
        given ($c) {
            when ('+') { ($tape[$p] += 1) %= 256;}
            when ('-') { ($tape[$p] -= 1) %= 256;}
            when ('>') { $p++; }
            when ('<') { $p--; }
            when ('.') { $out .= chr $tape[p]; }
            when (',') { my $_ = chop $inp; $tape[$p] = $_ if defined; }
            when ('[') {
                "$src[" =~ /( \] [^[\]]* | (?0) \[ )$/xp;
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
