package Trubble::Units;

use strict;
use warnings;
use IPC::Open3;


sub call {
    my ($body) = @_;
    $body =~ s/^(units|convert)\s*//;
    my @args = split(/\s+/, $body);

    @args = grep { !/-/ } @args;

    if (!scalar(@args)) {
        return "something stupid happened";
    }

    unshift(@args, "-t");
    unshift(@args, "units");

    my ($child_in, $child_out, $child_err);
    my $pid = open3($child_in, $child_out, $child_err, @args);

    binmode($child_out, ":utf8");

    waitpid($pid, 0);

    my @lines = <$child_out>;
    my $response = "";
    for my $line (@lines) {
        chomp($line);
        chomp($line);

        if (!$line) {
            next;
        }

        $response .= $line . " ";
    }

    my $ret = $?;
    if (!$ret) {
        return $response;
    } elsif ($ret == -1) {
        return "failed to execute: $!";
    } elsif ($ret & 127) {
        return sprintf("child died with signal %d, %s coredump", ($ret & 127),  ($ret & 128) ? "with" : "without");
    }  else {
        return $response;
    }
}

return 1;

