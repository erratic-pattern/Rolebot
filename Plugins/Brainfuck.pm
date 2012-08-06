package Rolebot::Plugins::Brainfuck;
use strict; use warnings;
use v5.10;
use Rolebot::Bot;
use Rolebot::Config;

sub context {
    my ($pre, $post) = @_;
    return substr($pre, -6, 6) . substr(reverse($post), 0, 6);
}

sub check_brackets {
    my $post = reverse @_;
    my ($pre, $bc, $i) = ('',0,0);
    while ('' ne (my $_ = chop $post)) {
        $pre .= $_;
        $i++;
        $bc++ if $_ eq '[';
        $bc-- if $_ eq ']';
        return ($i, sub {"Mismatched ] at column $i around: ".context($pre,$post)})
          if $bc < 0;
    }
    return undef if $bc == 0;
    return ($i, sub{"Missing ] at EOF"})
      if $bc > 0;
}


sub interpret {
    my ($_) = @_;
    my ($src, $inp) = /^(.*?)(?:!([^!]*))?$/;
    my @src = split //, $src;
    my @inp = split //, $inp;
    my (@stack, @tape);
    my ($p, $i, $out, $start_time) = (0,-1,'',time);
    while (++$i <= $#src) {
        #say $src[$i];
        #say @inp;
        #say $out;
        #say @tape;
        #say '';
        return "Time limit exceeded. Output: $out"
          if time - $start_time >= 12;
        return "Output limit exceeded. Output: $out"
          if length($out) > $Rolebot::Config::line_cap;
        given ($src[$i]) {
            when ('+') { ($tape[$p] += 1) %= 256;}
            when ('-') { ($tape[$p] -= 1) %= 256;}
            when ('>') { $p++; }
            when ('<') { $p-- if $p > 0; }
            when ('.') { $out .= chr($tape[$p]); }
            when (',') { $tape[$p] = ord (shift @inp // "\0");}
            when ('[') {
                if ($tape[$p]) {
                    push @stack, $i;
                }
                else {
                    ($i) = check_brackets(join('', @src[$i+1..$#src]));
                }
            }
            when (']') {
                if ($tape[$p]) {
                    $i = $stack[$#stack];
                }
                else {
                    pop @stack;
                }
            }
            when ('#') {
                my $prei = $p-3;
                $prei = 0 if $prei < 0;
                my $posti = $p+3;
                my $pre = join ' ', map {$_//0} @tape[$prei..$p-1];
                my $post = join ' ', map {$_//0} @tape[$p+1..$posti];
                my $x = $tape[$p] // 0;
                $out .= "($pre <$x> $post)";
            }
        }
    }
    return "No output." unless length $out;
    return $out;
}


command bf => Languages => 'bf <program>[!<input>] -- execute a brainfuck program with optional input. Use the # command to print out a section of the tape for debugging.',
sub {
    my ($self, $args) = @_;
    my $src = trim $args->{body};
    return (body => $args->{help}) unless $src;
    my ($i, $err_msg) = check_brackets $src;
    return (body => $err_msg->()) if defined $err_msg;
    return (body => interpret $src);
};

1;
