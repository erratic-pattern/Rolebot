#!/usr/bin/perl
package Rolebot::Plugins::Frink::Load;
use strict; use warnings;
use v5.10;
use IPC::Open3;

use Rolebot::Bot;

my $max_memory = 100000;  #in kilobytes
my $max_time   = 20;      #in seconds
my $run_frink = "$Rolebot::Bot::bot_dir/Plugins/Frink/run_frink.sh";

command frink => Languages => "Usage: frink <expression> -- Executes a frink expression. Frink is a powerful calculator program. See http://futureboy.us/frinkdocs/ for more information.",
sub {
    my ($self, $a) = @_;
    return (body => $a->{help}) unless my $expr = $a->{body};
    my $out;
    my $pid = open3(undef, $out, $out, $run_frink, $max_time, $max_memory, $expr);
    waitpid($pid, 0);
    local $/;
    return (body => <$out>);
};
