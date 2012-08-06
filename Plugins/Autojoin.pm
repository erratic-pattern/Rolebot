#!/usr/bin/perl
package Rolebot::Plugins::AutoJoin;
use strict; use warnings;
use v5.10;


our $auto_rejoin_time = 0.4;

sub kicked {
    my ($self, $a) = @_;
    say $a->{kicked};
    say $self->nick;
    say $a->{channel};
    if(lc $a->{kicked} eq lc $self->nick) {
        sleep $auto_rejoin_time;
        $self->join($a->{channel});
    }
}
