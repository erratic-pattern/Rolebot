#!/usr/bin/perl
package Rolebot::Plugins::Admin;
use strict; use warnings;
use v5.10;

use Rolebot::Bot;
use Rolebot::Config;
local $Rolebot::Config::default_help_category = 'Admin';

sub load {
    my ($self) = @_;
    my $state = $self->state;
    $state->{ignore} //= {};
    $state->{ignore_hosts} //= {};
}


sub said {
    my ($self, $args) = @_;
    my $nick = $args->{who};
    return if $self->is_admin($nick);
    for (keys %{$self->state->{ignore}}) {
        if (lc $nick eq lc $_) {
            %$args = ();
            return;
        }
    }
    my $host = $self->pocoirc->nick_info($nick)->{Host};
    return unless $host;
    for (keys %{$self->state->{ignore_host}}) {
        if($host =~ /$_/) {
            %$args = ();
            return;
        }
    }
    return;
}

command admin => 'Usage: admin (list|add|delete) [<nick1> <nick2> <nick3> ...]  -- admin manager command',
sub {
    my($self, $a) = @_;
    my $msg;
    my ($subcmd, $arg) = parse_subcommand $a->{body};
    $arg //= '';
    given ($subcmd) {
        when ('add') {
            if (!$self->is_admin($a->{who})) {
                $msg = 'Insufficient privileges';
            }
            elsif ($arg) {
                $self->admins($self->admins, split / +/, $arg);
                $msg = 'Done';
            }
        }
        when ('delete') {
            if (!$self->is_super_admin($a->{who})) {
                $msg = 'Insufficient privileges';
            }
            elsif ($arg) {
                my @arglist = split / +/, $arg;
                $self->admins(grep {my $o = $_; !grep {$_ eq $o} @arglist} $self->admins);
                $msg = 'Done';
            }
        }
        when ('list') {
            my @admins = $self->admins;
            $msg = "Admins: @admins";
        }
    }
    return (body => $msg || $a->{help});
};


sub get_hosts {
    my ($self, @nicks) = @_;
    my @no_host;
    my @ignore_list =
      map {
          my $info = $self->pocoirc->nick_info($_);
          if ($info && (my $host = $info->{Host})) {
              '^' . quotemeta($host) . '$';
          }
          else {
              push @no_host, $_;
              ();
          }
      } @nicks;
    return (\@ignore_list, \@no_host);
}

command ignore => 'Usage: ignore (nick|host) <nick1> [<nick2> ...] --or-- ignore pattern <host regex> --or-- ignore list -- ignores the specified nicks or hosts',
sub {
    my ($self, $a) = @_;
    return (body => "Insufficient privileges.") unless $self->is_admin($a->{who});
    my ($subcmd, $args) = parse_subcommand(trim $a->{body});
    $args //= '';
    given ($subcmd) {
        when (/^(nick|host)$/) {
            my $ignore_type = $1;
            my @ignore_list = split /\s+/, trim $args;
            return (body => $a->{help}) unless @ignore_list;
            for my $n (@ignore_list) {
                return (body => "Can't ignore admins.") if $self->is_admin($n);
            }
            my $ignore;
            if ($ignore_type eq 'nick') {
                $self->state->{ignore}->{$_} = $_? 1 : undef for @ignore_list;
            }
            elsif ($ignore_type eq 'host') {
                my ($hosts, $no_hosts) = get_hosts($self, @ignore_list);
                $self->state->{ignore_host}->{$_} = $_? 1 : undef for @$hosts;
                if (@$no_hosts) {
                    $self->say(%$a, body => 'Couldn\'t find hosts for the following nicks: ' . join ' ', @$no_hosts);
                }
            }
        }
        when ('pattern') {
            return (body => $a->{help}) unless $args;
            $self->state->{ignore_host}->{$args} = 1;
        }
        when ('list') {
            my $sep = "\x{3}2|\x{F}";
            my $msg = "Ignored nicks: @{[keys %{$self->state->{ignore}}]}";
            $msg   .= " $sep Ignored hosts: @{[keys %{$self->state->{ignore_host}}]}";
            return (body => $msg );
        }
        default {
            return (body => $a->{help});
        }
    }
    return (body => "Done.");
};

command unignore => 'Usage: unignore (nick|host) <nick1> [<nick2> ...] --or-- unignore pattern <host regex> -- unignores the specified nicks or hosts',
sub {
    my ($self, $a) = @_;
    return (body => "Insufficient privileges.") unless $self->is_admin($a->{who});
    my ($subcmd, $args) = parse_subcommand(trim $a->{body});
    my ($ignore, @unignore_list);
    return (body => $a->{help}) unless $args;
    given ($subcmd) {
        when ('nick') {
            @unignore_list = split /\s+/, trim $a->{body};
            delete $self->state->{ignore}->{$_} for @unignore_list;
        }
        when ('host') {
            @unignore_list = split /\s+/, $args;
            my ($hosts, $no_hosts) = get_hosts($self, @unignore_list);            
            delete $self->state->{ignore_host}->{$_} for @$hosts;
            if(@$no_hosts) {
                $self->say(%$a, body => 'Couldn\'t find hosts for the following nicks: ' . join ' ', @$no_hosts);
            }         
        }
        when (/host|pattern/) {
            delete $self->state->{ignore_host}->{$args}
        }
        default {
            return (body => $a->{help});
        }
    }
    return (body => "Done.");
};

command shutdown => 'Bot shutdown.',
sub {
    my ($self, $who) = (shift, shift->{who});
    $self->shutdown("manual shutdown by $who") if $self->is_super_admin($who);
    return (body=>"I'm sorry $who, I'm afraid I can't do that.");
};
