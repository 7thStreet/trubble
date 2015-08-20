package Trubble;

use strict;
use warnings;
use base 'Bot::BasicBot';

use Carp;
use Time::Piece;

use DBI;
use Config::Tiny;
use POE qw(Component::Server::TCP);
use URI::Escape;

use Trubble::Advice;
use Trubble::Excuses;
use Trubble::Pokemon;
use Trubble::Units;
use Trubble::Magic8Ball;
use Trubble::TFW;
use Trubble::Lunch;
use Trubble::Countdown;
use Trubble::Dinklage;
use Trubble::Random;


my %recent_pastes = ();
my %recent_changes = ();
my %recent_tickets = ();
my %recent_jira_tickets = ();
my $config = Config::Tiny->new();

my $trac_enabled = 0;
my $jira_enabled = 0;

my %channels = ();

sub init {
    my $self = shift;

    $config = $config->read("config.ini") or die Config::Tiny->errstr;
    $config->{main}->{channel} = "#".$config->{main}->{channel};

    $channels{$config->{main}->{channel}} = 1;

    if ($config->{trac} && $config->{trac}->{enabled} && $config->{trac}->{enabled} =~ /true/i) {
        $trac_enabled = 1;
    }

    if ($config->{jira} && $config->{jira}->{enabled} && $config->{jira}->{enabled} =~ /true/i) {
        $jira_enabled = 1;
    }

    %recent_pastes = $self->get_pastes();
    %recent_changes = $self->get_changes();
    %recent_tickets = $self->get_tickets();

    # for mercurial
    my $client_input = sub {
        my $input = $_[ARG0];
        for my $channel (keys %channels) {
            $self->say(channel => $channel, body => $input);
        }
    };

    POE::Component::Server::TCP->new(
        Port => $config->{hg}->{port},
        ClientInput => $client_input,
    );

    return 1;
}

sub said {
    my $self = shift;

    my $args = shift;
    my $who = $args->{who};
    my $channel = $args->{channel};
    my $body = $args->{body};
    my $addressed = $args->{address};

    my $nick = $config->{main}->{nick};

    my $trail = qr/[:,]/;
    if ($body =~ /^$nick$trail/) {
        $body =~ s/^$nick$trail\s*//;
    }

    my $msg = undef;

    # give out karma
    my $is_karma = 0;
    {
        my $kbody = $body . "";
        $kbody =~ s/\W(--|\+\+)(\(.*?\)|[^(++)(--)\s]+)/$2$1/;
        while ($kbody =~ s/(\(.*?\)|[^(++)(--)\s]+)(\+\+|--)//) {
            my ($item, $increment) = ($1, $2);

            # try to normalize items
            $item = lc($item);
            $item =~ s/^\((.*)\)$/$1/;
            $item =~ s/\s+/ /g;

            next if $item eq "";

            if ($increment eq "--") {
                $increment = -1;
            } elsif ($increment eq "++") {
                $increment = 1;
            } else {
                $increment = 0;
            }

            $self->set_karma($item, $increment);

            $is_karma = 1;
        }
    }

    if ($addressed && $body =~ /^join:?\s+(.*)/) {
        my $channel = $1;
        $self->join($channel);
        $self->_update_channels();
        $channels{$channel} = 1;
    } elsif ($addressed && $body =~ /^karma\s+(.*)/) {
        my $item = $1;
        my $original_item = $item . "";

        # try to normalize items
        $item = lc($item);
        $item =~ s/^\((.*)\)$/$1/;
        $item =~ s/\s+/ /g;

        my $karma = $self->get_karma($item);
        if (!$karma) {
            $msg = "$original_item has neutral karma";
        } else {
            $msg = "$original_item has karma of $karma";
        }
    } elsif ($body =~ /^lunch\??$/) {
        $msg = Trubble::Lunch::get_response();
    } elsif ($addressed && $body =~ /^((countdown (to|for))|(days (since|without))) (.*)/) {
        $msg = Trubble::Countdown::get_countdown($2, $4, $6);
    } elsif ($trac_enabled && $body =~ m!\bticket(\s+|/)#?(\d+)!) {
        my $ticket = $2;

        my $row = $self->get_ticket($ticket);
        if ($row) {
            my $type = $row->{type};
            my $owner = $row->{owner};
            my $reporter = $row->{reporter};
            my $status = $row->{status};
            my $summary = $row->{summary};

            my $base = $config->{trac}->{link_base};
            my $url = "$base/ticket/$ticket";

            $msg = "#$ticket: $summary (reported by: '$reporter' owned by: '$owner' status: '$status') $url";
        } else {
            $msg = "couldn't find ticket #$ticket";
        }
    } elsif ($jira_enabled && $body =~ /jira\s+(\w+-\d+)/) {
        my $ticket = $1;

        my $row = $self->get_jira_ticket($ticket);
        if ($row) {
            my $assignee = $row->{assignee};
            my $reporter = $row->{reporter};
            my $status = $row->{pname};
            my $summary = $row->{summary};

            my $base = $config->{jira}->{link_base};
            my $url = "$base/browse/$ticket";

            $msg = "$ticket: $summary (reported by: '$reporter' owned by: '$assignee' status: '$status') $url";
        } else {
            $msg = "couldn't find ticket '$ticket'";
        }
    } elsif ($addressed && $body =~ /^(clock|date|time)/) {
        my $action = $1;
        my $t = localtime;
        
        if($action eq "clock") {
            $msg = $t->strftime("%T");
        } elsif ($action eq "date") {
            $msg = $t->strftime("%F");
        } elsif ($action eq "time") {
            $msg = $t->strftime("%s");
        }
    } elsif ($addressed && $body =~ /^advice/) {
        $msg = Trubble::Advice::get_advice();
    } elsif ($addressed && $body =~ /^excuse/) {
        $msg = Trubble::Excuses::get_excuse();
    } elsif ($addressed && $body =~ /^pokemon/) {
        $msg = Trubble::Pokemon::get_pokemon();
    } elsif ($addressed && $body =~ /^itwill/) {
        $msg = `itwill`;
    } elsif ($addressed && $body =~ /^(units|convert)/) {
        $msg = Trubble::Units::call($body);
    } elsif ($addressed && $body =~ /^8ball/) {
        $msg = Trubble::Magic8Ball::get_answer();
    } elsif ($addressed && $body =~ /^summon/) {
        $msg = Trubble::Summon::summon($who, $body);
    } elsif ($addressed && $body =~ /^tfw/) {
        $msg = Trubble::TFW::tfw($body);
    } elsif ($addressed && $body =~ /^tfwc/) {
        $msg = Trubble::TFW::tfwc($body);
    } elsif ($addressed && $body =~ /^weather/) {
        $msg = Trubble::Weather::weather($body);
    } elsif ($addressed && $body =~ /^random/) {
        $msg = Trubble::Random::choose($body);
    } elsif ($addressed && $body =~ /^(literal|forget) (.*)/) {
        my $action = $1;
        my $key = $2;
        $key =~ s/^\s+|\s+$//g;
        my $lower = lc($key);

        if ($action eq "literal") {
            my $fact = $self->get_literal_factoid($lower);
            if ($fact) {
                $msg = $key . " =is= " . $fact;
            } else {
                $msg = "I haven't a clue"
            }
        } elsif ($action eq "forget") {
           $self->delete_factoid($lower);
           $msg = "ok";
        }
    } elsif ($addressed && $body =~ /^(.*?) (is also|is|are also|are) (.*)/) {
        my $key = $1;
        my $fact = $3;
        my $lower = lc($key);

        $self->set_factoid($lower, $fact);
        $msg = "ok";
    } elsif ($addressed && $body =~ /^\s*point\s+the\s+finger\s*[?!]?\s*$/) {
        $msg = "aditya";
    } else { # maybe get a factoid
        my $key = $body . "";
        $key =~ s/[?!]+$//;
        $key =~ s/^\s+|\s+$//g;
        my $lower = lc($key);

        my $fact = $self->get_factoid($lower, $who);
        if ($fact) {
            if ($fact =~ /^\s*<reply>\s*/) {
                $fact =~ s/^\s*<reply>\s*//;
                $self->say(channel => $channel, who => $who, body => $fact);
            } elsif ($fact =~ /^\s*<action>\s*/) {
                $fact =~ s/^\s*<action>\s*//;
                $self->emote(channel => $channel, who => $who, body => $fact);
            } elsif ($addressed) {
                $msg = "I heard that $key was $fact";
            }
        } else {
            if ($addressed && !$is_karma) {
                $msg = "I haven't a clue";
            }
        }
    }

    if (!defined($msg)) {
        $msg = Trubble::Dinklage::check_for_dinklage($body);
    }

    if ($msg) {
        $msg =~ tr/\n/ /;
    }

    return $msg;
}

sub _update_channels {
    my $self = shift;

    for my $channel (keys %channels) {
        delete $channels{$channel};
    }

    for my $channel (keys %{$self->{IRCOBJ}->channels()}) {
        $channels{$channel} = 1;
    }
}

sub kicked {
    my $self = shift;
    my $ref = shift;

    $self->_update_channels();
}

sub invited {
    my $self = shift;
    my $args = shift;

    my $channel = $args->{channel};

    $self->join($channel);
    $self->_update_channels();
    $channels{$channel} = 1;
}

sub get_factoid {
    my ($self, $key, $who) = @_;

    my $fact = $self->get_literal_factoid($key);
    if (!$fact) {
        return undef;
    }
    
    my @parts = split(/(?<!\\)\|/, $fact);
    my $part = $parts[int(rand(scalar(@parts)))];

    $part =~ s/\\\|/|/g;

    $part =~ s/\$who\b/$who/g;

    return $part;
}

sub get_literal_factoid {
    my ($self, $key) = @_;

    my $db = $config->{facts}->{db};
    my $dbh = DBI->connect($db, "", "", { AutoCommit => 0, sqlite_unicode => 1 });

    $dbh->do("create table if not exists facts (key, value)");
    $dbh->commit();

    my $sth = $dbh->prepare("select key, value from facts where key = ?");
    $sth->bind_param(1, $key);

    $sth->execute();
    my $row = $sth->fetchrow_hashref();

    $sth->finish();
    $dbh->commit();
    $dbh->disconnect();

    if (!$row) {
        return undef;
    }

    my $fact = $row->{value};
    return $fact;
}

sub set_factoid {
    my ($self, $key, $fact) = @_;

    my $db = $config->{facts}->{db};
    my $dbh = DBI->connect($db, "", "", { AutoCommit => 0, sqlite_unicode => 1 });

    $dbh->do("create table if not exists facts (key, value)");
    $dbh->commit();

    my $sth = $dbh->prepare("select key, value from facts where key = ?");
    $sth->bind_param(1, $key);

    $sth->execute();
    my $row = $sth->fetchrow_hashref();
    $sth->finish();

    if (!$row) {
        my $insert = $dbh->prepare("insert into facts (key, value) values (?, ?)");
        $insert->bind_param(1, $key);
        $insert->bind_param(2, $fact);
        $insert->execute();
        $insert->finish();
    } else {
        my $value = $row->{value} . " or " . $fact;
        if ($fact =~ /^\s*\|/) {
            $value =  $row->{value} . $fact
        }

        my $update = $dbh->prepare("update facts set value = ? where key = ?");
        $update->bind_param(1, $value);
        $update->bind_param(2, $key);
        $update->execute();
        $update->finish();
    }

    $dbh->commit();
    $dbh->disconnect();
}

sub delete_factoid {
    my ($self, $key) = @_;

    my $db = $config->{facts}->{db};
    my $dbh = DBI->connect($db, "", "", { AutoCommit => 0, sqlite_unicode => 1 });

    $dbh->do("create table if not exists facts (key, value)");
    $dbh->commit();

    my $sth = $dbh->prepare("delete from facts where key = ?");
    $sth->bind_param(1, $key);

    $sth->execute();
    $sth->finish();
    $dbh->commit();
    $dbh->disconnect();
}

sub get_karma {
    my ($self, $item) = @_;

    my $db = $config->{facts}->{db};
    my $dbh = DBI->connect($db, "", "", { AutoCommit => 0, sqlite_unicode => 1 });

    $dbh->do("create table if not exists karma (item primary key, value default 0)");
    $dbh->commit();

    my $sth = $dbh->prepare("select item, value from karma where item = ?");
    $sth->bind_param(1, $item);

    $sth->execute();
    my $row = $sth->fetchrow_hashref();

    $sth->finish();
    $dbh->commit();
    $dbh->disconnect();

    if (!$row) {
        return undef;
    }

    my $fact = $row->{value};
    return $fact;
}

sub set_karma {
    my ($self, $item, $increment) = @_;

    my $db = $config->{facts}->{db};
    my $dbh = DBI->connect($db, "", "", { AutoCommit => 0, sqlite_unicode => 1 });

    $dbh->do("create table if not exists karma (item primary key, value default 0)");
    $dbh->commit();

    my $sth = $dbh->prepare("select item, value from karma where item = ?");
    $sth->bind_param(1, $item);

    $sth->execute();
    my $row = $sth->fetchrow_hashref();
    $sth->finish();

    my $karma;

    if (!$row) {
        my $insert = $dbh->prepare("insert into karma (item, value) values (?, ?)");
        $insert->bind_param(1, $item);
        $insert->bind_param(2, $increment);
        $insert->execute();
        $insert->finish();
    } else {
        my $update = $dbh->prepare("update karma set value = ? where item = ?");
        $update->bind_param(1, $row->{value} + $increment);
        $update->bind_param(2, $item);
        $update->execute();
        $update->finish();
    }

    $dbh->commit();
    $dbh->disconnect();
}

sub get_ticket {
    my ($self, $ticket) = @_;

    my $query = "select type, component, owner, reporter, milestone, status, summary from trac.ticket where id = $ticket";

    my $db = $config->{trac}->{db};
    my $user = $config->{trac}->{db_user};
    my $pass = $config->{trac}->{db_pass};
    my $dbh = DBI->connect($db, $user, $pass, { sqlite_unicode => 1 });

    my $row = $dbh->selectrow_hashref($query);
    return $row;
}

sub get_jira_ticket {
    my ($self, $ticket) = @_;

    my $query = "select pkey, assignee, reporter, summary, pname from jiraissue join issuestatus on jiraissue.issuestatus = issuestatus.id where pkey = '$ticket'";

    my $db = $config->{jira}->{db};
    my $user = $config->{jira}->{db_user};
    my $pass = $config->{jira}->{db_pass};
    my $dbh = DBI->connect($db, $user, $pass, { sqlite_unicode => 1 });
    my $row = $dbh->selectrow_hashref($query);
    $dbh->disconnect();

    return $row;
}

sub tick {
    my $self = shift;

    if ($config->{main}->{debug} && $config->{main}->{debug} =~ /true/i) {
        for my $channel (keys %channels) {
            $self->say(channel => $channel, body => "NINE");
        }
    }

    # pastes
    my %latest_pastes = $self->get_pastes();
    my @new_pastes = grep { !defined($recent_pastes{$_}) } keys %latest_pastes;
    %recent_pastes = %latest_pastes;

    foreach my $key (@new_pastes) {
        my $frag = $latest_pastes{$key}->{frag};
        my $username = $latest_pastes{$key}->{username};
        my $base = $config->{lodgeit}->{link_base};

        my $body = "'$username' pasted '$frag' at $base/show/$key/";
        $body =~ tr/\n/ /;
        for my $channel (keys %channels) {
            $self->say(channel => $channel, body => $body);
        }
    }

    # changes
    my %latest_changes = $self->get_changes();
    my @new_changes = grep { !defined($recent_changes{$_}) } keys %latest_changes;
    %recent_changes = %latest_changes;

    foreach my $key (@new_changes) {
        my $ticket = $latest_changes{$key}->{ticket};
        my $field = $latest_changes{$key}->{field};
        my $author = $latest_changes{$key}->{author};
        my $name = $latest_changes{$key}->{name};
        my $version = $latest_changes{$key}->{version};
        my $comment = $latest_changes{$key}->{comment};

        my $body;

        if (defined($ticket)) {
            my $oldvalue = $latest_changes{$key}->{oldvalue};
            my $newvalue = $latest_changes{$key}->{newvalue};
            if ($field eq "status") {
                $body = "$author changed the status of #$ticket from '$oldvalue' to '$newvalue'";
            } elsif ($field eq "owner") {
                $body = "$author changed the owner of #$ticket from '$oldvalue' to '$newvalue'";
            } elsif ($field eq "comment") {
                $body = "$author added a comment to #$ticket";
            } else {
                carp("unknown field '$field'");
            }
        } elsif (defined($name)) {
            my $base = $config->{trac}->{link_base};
            my $url = "$base/wiki/" . uri_escape($name) . "?action=diff&version=$version";
            $body = "$author edited $name: $url";
            if ($comment) {
                $body .= " " . $comment;
            }
        } else {
            next;
        }

        $body =~ tr/\n/ /;
        for my $channel (keys %channels) {
            $self->say(channel => $channel, body => $body);
        }
    }

    # tickets
    if ($trac_enabled) {
        my %latest_tickets = $self->get_tickets();
        my @new_tickets = grep { !defined($recent_tickets{$_}) } keys %latest_tickets;
        %recent_tickets = %latest_tickets;

        foreach my $key (@new_tickets) {
            my $ticket = $latest_tickets{$key}->{ticket};
            my $reporter = $latest_tickets{$key}->{reporter};
            my $owner = $latest_tickets{$key}->{owner};
            my $summary = $latest_tickets{$key}->{summary};

            my $base = $config->{trac}->{link_base};
            my $url = "$base/ticket/$ticket";

            my $body = "$reporter created ticket #$ticket for $owner: $summary $url";
            $body =~ tr/\n/ /;
            for my $channel (keys %channels) {
                $self->say(channel => $channel, body => $body);
            }
        }
    }

    # jira tickets
    if ($jira_enabled) {
        my %latest_jira_tickets = $self->get_jira_tickets();
        my @new_jira_tickets = grep { !defined($recent_jira_tickets{$_}) } keys %latest_jira_tickets;
        %recent_jira_tickets = %latest_jira_tickets;

        foreach my $key (@new_jira_tickets) {
            my $ticket = $latest_jira_tickets{$key}->{ticket};
            my $reporter = $latest_jira_tickets{$key}->{reporter};
            my $assignee = $latest_jira_tickets{$key}->{assignee};
            my $summary = $latest_jira_tickets{$key}->{summary};

            my $base = $config->{jira}->{link_base};
            my $url = "$base/browse/$ticket";

            my $body = "$reporter created ticket $ticket for $assignee: $summary $url";
            $body =~ tr/\n/ /;
            for my $channel (keys %channels) {
                $self->say(channel => $channel, body => $body);
            }
        }
    }

    return 30;
}

sub get_pastes {
    my $self = shift;

    my $db = $config->{lodgeit}->{db};
    my $user = $config->{lodgeit}->{db_user};
    my $pass = $config->{lodgeit}->{db_pass};
    my $dbh = DBI->connect($db, $user, $pass, { sqlite_unicode => 1 });

    my $res = $dbh->selectall_arrayref("select paste_id, code, username from pastes order by paste_id desc limit 10");

    my %pastedata = ();
    foreach my $row (@{$res}) {
        my $frag = $row->[1];
        if (!defined($frag)) {
            $frag = "";
        }

        if (length($frag) > 40) {
            $frag = substr($frag, 0 ,40) . "...";
        }
        my $username = $row->[2];
        if (!defined($username)) {
            $username = "";
        }

        $pastedata{$row->[0]}->{username} = $username;
        $pastedata{$row->[0]}->{frag} = $frag;

    return %pastedata    
    }
}

sub get_changes {
    my $self = shift;

    my $db = $config->{trac}->{db};
    my $user = $config->{trac}->{db_user};
    my $pass = $config->{trac}->{db_pass};
    my $dbh = DBI->connect($db, $user, $pass, { sqlite_unicode => 1});

    my $query = <<END;
        select
            ticket,
            time,
            author,
            field,
            oldvalue,
            newvalue
        from
            trac.ticket_change
        where
            field in ('status', 'owner', 'comment')
            or field like '_comment%'
        order by
            time desc
        limit 20
END

    my $res = $dbh->selectall_arrayref($query);

    my %changes = ();
    foreach my $row (@{$res}) {
        my $ticket = $row->[0];
        my $time = $row->[1];
        my $author = $row->[2];
        my $field = $row->[3];
        my $oldvalue = $row->[4];
        my $newvalue = $row->[5];

        my $key = $ticket . "." . $time;

        if ($field =~ /comment/) {
            $field = "comment";
        }

        $changes{$key}->{ticket} = $ticket;
        $changes{$key}->{author} = $author;

        if (defined($changes{$key}->{field})) {
            my $cur_field = $changes{$key}->{field};

            # owner > status > everything else
            if (!($cur_field eq "owner" || ($cur_field eq "status" && $field ne "owner"))) {
                $changes{$key}->{field} = $field;
                $changes{$key}->{oldvalue} = $oldvalue;
                $changes{$key}->{newvalue} = $newvalue;
            }
        } else {
            $changes{$key}->{field} = $field;
            $changes{$key}->{oldvalue} = $oldvalue;
            $changes{$key}->{newvalue} = $newvalue;
        }
    }

    my $wquery = <<END;
        select
            name,
            time,
            author,
            version,
            comment
        from
            wiki
        order by
            time desc
        limit 20
END

    my $wres = $dbh->selectall_arrayref($wquery);

    foreach my $wrow (@{$wres}) {
        my $name = $wrow->[0];
        my $time = $wrow->[1];
        my $author = $wrow->[2];
        my $version = $wrow->[3];
        my $comment = $wrow->[4];

        my $key = $name . "." . $time;

        $changes{$key}->{name} = $name;
        $changes{$key}->{author} = $author;
        $changes{$key}->{version} = $version;
        $changes{$key}->{comment} = $comment;
    }

    return %changes;
}

sub get_tickets {
    my $self = shift;

    my $db = $config->{trac}->{db};
    my $user = $config->{trac}->{db_user};
    my $pass = $config->{trac}->{db_pass};
    my $dbh = DBI->connect($db, $user, $pass, { sqlite_unicode => 1 });

    my $query = <<END;
        select
            id,
            reporter,
            owner,
            summary,
            time
        from
            trac.ticket 
        order by
            time desc
        limit 10
END

    my $res = $dbh->selectall_arrayref($query);

    my %tickets = ();
    foreach my $row (@{$res}) {
        my $ticket = $row->[0];
        my $reporter = $row->[1];
        my $owner = $row->[2];
        my $summary = $row->[3];
        my $time = $row->[4];

        my $key = $ticket . "." . $time;

        $tickets{$key}->{ticket} = $ticket;
        $tickets{$key}->{reporter} = $reporter;
        $tickets{$key}->{owner} = $owner;
        $tickets{$key}->{summary} = $summary;
    }

    return %tickets;
}

sub get_jira_tickets {
    my $self = shift;

    my $db = $config->{jira}->{db};
    my $user = $config->{jira}->{db_user};
    my $pass = $config->{jira}->{db_pass};

    my $dbh = DBI->connect($db, $user, $pass, { sqlite_unicode => 1 });
    my $query = <<END;
        select
            pkey,
            reporter,
            assignee,
            summary,
            created
        from
            jiraissue
        order by
            created desc
        limit 10
END

    my $res = $dbh->selectall_arrayref($query);

    my %tickets = ();
    foreach my $row (@{$res}) {
        my $ticket = $row->[0];
        my $reporter = $row->[1];
        my $assignee = $row->[2];
        my $summary = $row->[3];
        my $created = $row->[4];

        my $key = $ticket . "." . $created;

        $tickets{$key}->{ticket} = $ticket;
        $tickets{$key}->{reporter} = $reporter;
        $tickets{$key}->{assignee} = $assignee;
        $tickets{$key}->{summary} = $summary;
    }

    $dbh->disconnect();

    return %tickets;
}

return "Abandon all hope, ye who return from here"; 


