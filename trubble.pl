#!/usr/bin/env perl

use strict;
use warnings;

use Config::Tiny;

use Trubble;

my $config = Config::Tiny->new();
$config = $config->read("config.ini") or die Config::Tiny->errstr;

my $server = $config->{main}->{server};
my $port = $config->{main}->{port};
my $channel = "#".$config->{main}->{channel};
my $nick = $config->{main}->{nick};
my $username = $config->{main}->{username};

my $bot = Trubble->new(
    server => $server,
    port => $port,
    channels => [$channel],
    nick => $nick,
    username => $username,
);

$bot->run();

