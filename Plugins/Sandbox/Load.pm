package Rolebot::Plugins::Sandbox::Load;
use strict; use warnings;
use v5.10;
use Rolebot::Bot;
use Rolebot::Config;
use Symbol;
use IPC::Open3;
use File::chdir;
use File::stat;
use String::ShellQuote;
use Storable 'dclone';

local $Rolebot::Config::default_help_category = "Sandbox";

my $dir = "$Rolebot::Bot::bot_dir/Plugins/Sandbox";
my $home = "$dir/home";

my $commit_log = "$dir/commits.log";
my $revert_log = "$dir/reverts.log";
my $cmd_log = "$dir/cmds.log";

my $commit_changes = "$dir/commit_changes.sh";
my $run_cmd = "$dir/run_cmd.sh";

sub load {
    my ($self) = @_;
    unless (-d "$dir/home") {
        `mkdir "$home"`;
    }
    unless (-d "$dir/.git") {
        `cd '$dir'; git init`;
        commit_changes("First commit.", $self->nick);
    }
    my $cmds = ($self->state->{cmds} //= {});
    for(keys %$cmds) {
        bind_command($self, $_, @{$cmds->{$_}});
        my ($cat, $code) = @{$cmds->{$_}};
        `mkdir -p $home/cmds/$cat` if $cat;
        my $path = $cat? "$home/cmds/$cat/$_" : "$home/cmds/$_";
        open my $f, ">$path";
        say $f $code;        
    }
}

# sub cmd_hook {
#     my ($self, $cmds) = @_;
#     local $self->{cmds} = $cmds;
#     my $cmd_dir = "$home/cmds";
#     return unless -d $cmd_dir;
#     for (`ls -AB $cmd_dir`) {
#         chomp;
#         my ($name, $path) = ($_, "$home/cmds/$_");
#         if (-d $path) {
#             my $dquoted;
#             eval { $dquoted = shell_quote $path };
#             next if $@;
#             for (`ls -AB $dquoted/$_`) {
#                 chomp;
#                 next unless -f;
#                 open my $f, '<', "$path/$_";
#                 bind_command($self, $_, $name, join('', <$f>));
#             }
#         }
#         elsif (-f $path) {
#             open my $f, '<', $path;
#             bind_command($self, $name, undef, join('', <$f>));
#         }
#     }
# }

sub help_query {
    my ($self, $args) = @_;
    my $query = trim $args->{body};
    return if $args->{found} || $query =~ /\.\.?/;
    my $help;
    if (open my $f, '<', "$home/help/$query") {
        local $/;
        $help = <$f>;
        close $f;
        $args->{found} = 1;
    }
    return (body => $help) if $args->{found};
    return;
}


sub log_to {
    my ($fname, @out) = @_;
    open my $f, ">>$fname";
    print $f $_ for @out;
    close $f;
}

sub commit_changes {
    my ($msg, $nick) = @_;
    my $commit_out;
    my $pid = open3(undef, $commit_out, $commit_out, $commit_changes, $msg, $nick || 'unknown');
    waitpid($pid, 0);
    log_to($commit_log, <$commit_out>);
}

sub condense_output {
    my $str = join '', @_;
    chomp $str;
    my ($display, $current_line, $lines) = ('','',1);
    for (split /\n/, $str) {
        if (length ($current_line.$_) > $Rolebot::Config::line_cap) {
            $current_line =~ s/ \\ $/\n/;
            $display .= $current_line;
            $current_line = '';
            last if $lines++ > $Rolebot::Config::max_lines;
        }
        $current_line .= "$_ \\ ";
    }
    $current_line =~ s/ \\ $//;
    $display .= $current_line;
    return $display;
}

sub run_cmd {
    my ($author, $cmd, @args) = @_;;
    my $cmd_out;
    my $pid = open3(undef, $cmd_out, $cmd_out, $run_cmd, $cmd, @args);
    waitpid($pid, 0);
    my $out;
    {
        local $/;
        $out = <$cmd_out>;
    }
    log_to($cmd_log, "$out\n");
    commit_changes($cmd, $author);
    return $out;
}

command '`' => "Usage: ` <cmd> -- runs a bash command in a linux sandbox",
sub {
    my ($self, $args) = @_;
    return (body => "No.") if $args->{who} eq 'msg';
    my $cmd = trim $args->{body};
    return (body => $args->{help}) unless $cmd;
    my $out = condense_output (run_cmd($args->{who}, $cmd));
    return (body => 'No output.') unless $out;
    return (body => $out);
};

command fetch => "Usage: fetch <url> -- downloads a URL to the sandbox",
sub {
    my ($self, $args) = @_;
    my $url = trim $args->{body};
    return (body => "No.") if $args->{who} eq 'msg';
    return (body => $args->{help}) unless $url;
    eval { $url = shell_quote $url };
    return (body => "Unable to shell quote URL.") if $@;
    my $out = `cd $home; ulimit -t 15; ulimit -f 10240; wget -nv -- $url < /dev/null 2>&1 | tr "\n" ' ' | tee '$dir/wget.log'`;
    commit_changes("fetched $url", $args->{who});
    return (body => $out);
};

command paste => 'Usage: paste <file> -- paste a file relative to sandbox $HOME',
sub {
    my ($self, $args) = @_;
    return (body => "No.") if $args->{who} eq 'msg';
    my $path = trim $args->{body};
    return (body => $args->{help}) unless $path && $path !~ /\.\.(\/|$)/;
    $path = "$home/$path";
    return (body => "Not a file.") unless -f $path;
    my (@mime, $mime_out);
    @mime = (qw(xdg-mime query filetype), $path);
    waitpid(open3(undef, $mime_out, undef, @mime), 0);
    my ($url, $key);
    {
        local $/;
        if (<$mime_out> =~ /image/) {
            ($url, $key) = ('http://img.vim-cn.com/', 'name');
        }
        else {
            ($url, $key) = ('http://sprunge.us/', 'sprunge');
        }
    }
    my @curl = ('curl', '-sSF', "$key=\@$path", $url);
    my $out;
    my $pid = open3(undef, $out, $out, @curl);
    waitpid($pid, 0);
    local $/;
    $out = <$out>;
    return (body => $out);
};



command revert => 'Usage: revert <refspec1> [<refspec2 <refspec3 ...] -- reverts changes introduced by a given revision specifier. See "man gitrevisions" for more information about the syntax.',
sub {
    my ($self, $args) = @_;
    my $refs = trim $args->{body};
    return (body => $args->{help}) unless $refs;
    my $nick = $args->{who};
    local $CWD = $home;
    my $cmd_out;
    my $pid = open3(undef, $cmd_out, $cmd_out, "git revert --strategy=resolve -- $refs");
    waitpid($pid, 0);
    my $out;
    {
        local $/;
        $out = <$cmd_out>;
    }
    log_to($revert_log, "$out\n");
    return (body => condense_output $out);
};

sub bind_command {
    my ($self, $cmd, $category, $code) = @_;
    local $Rolebot::Bot::current_bot = $self;
    command $cmd, $category, '',
      sub {
          my ($self, $args) = @_;
          my $body = trim $args->{body};
          my $out = condense_output(run_cmd($args->{who}, $code, $body, split(/\s+/, $body)));
          return (body => 'No output.') unless $out;
          return (body => $out);
      };
    my $cdata = $self->{cmds}->{$cmd};
    $cdata->{sandboxed} = 1;
    $cdata->{plugin} = 'Sandbox';
    $self->state->{cmds}->{$cmd} = [$category, $code];
}

command bind => 'Usage: bind <command> (<category>|none) <code> -- binds a bot command to the given shell script. you can use numeric variables $1, $2, etc to refer to individual words, $@ to refer to every word with redundant spaces stripped, and $0 to refer to the raw line.',
sub {
    my ($self, $args) = @_;
    return (body => $args->{help}) 
      unless my ($cmd, $cat, $code) = $args->{body} =~ /^\s*(\S+) (\S+) (.+)$/;
    return (body => "Command already exists.") if $self->{cmds}->{$cmd};
    $cat = '' if $cat eq 'none';
    bind_command($self, $cmd, $cat, $code);
    return (body => 'Done.');
};


command unbind => 'Usage: unbind <command> -- removes a sandboxed command previously defined by bind',
sub {
    my ($self, $args) = @_;
    my $cmd = trim $args->{body};
    return (body => $args->{help}) unless $cmd;
    return (body => 'No such command.') unless my $cdata = $self->{cmds}->{$cmd};
    return (body => q(That's not a sandboxed command.)) unless $cdata->{sandboxed};
    delete $self->{cmds}->{$cmd};
    my ($cat, $code) = @{$self->state->{cmds}->{$cmd}};
    delete $self->state->{cmds}->{$cmd};
    return (body => "Done. Category: $cat; Code: $code");
};

command showcode => 'Usage: showcode <command> -- shows the shell code of a sandboxed command.',
sub {
    my ($self, $args) = @_;
    my $cmd = trim $args->{body};
    return (body => $args->{help}) unless $cmd;
    return (body => 'No such command.') unless my $cdata = $self->{cmds}->{$cmd};
    return (body => q(That's not a sandboxed command.)) unless $cdata->{sandboxed};
    return (body => $self->state->{cmds}->{$cmd}->[1]);

};

1;
