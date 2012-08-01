#!/usr/bin/perl

use strict;
use warnings;

use Nagios::Plugin;
use Minecraft::RCON;
use File::Basename;

my $VERSION = "1.0";
my $PROGNAME = basename($0);

my $p = Nagios::Plugin->new(
    usage => "Usage: %s [-H|--host <host>] ([ -P|--port <port> ])
    [ -p|--password <password> ]
    ([ -c|--critical=<critical threshold> ]) 
    ([ -w|--warning=<warning threshold> ])
    ",
    version => $VERSION,
    blurb => 'This plugin uses the Minecraft RCON protocol to connect to a remote
Bukkit/Minecraft server, run the \'/list\' command, parses the result, and
returns the number of players for monitoring with Nagios.',

	extra => "

THRESHOLDs for -w and -c are specified according to the standard Nagios range
format, documented here on the Nagios plug-in development guidelines page:

http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT

This range format is counter-intuitive, so please be sure to read the document
carefully, and pay particular attention to Table 3: Example Ranges. 


  Threshold example:

  Warn when playercount >18 and critical when playercount >19:

  $PROGNAME -w :18 -c :19
  "
);

$p->add_arg(
	spec => 'warning|w=s',
	help => 
qq{-w, --warning=MIN:MAX
   Minimum and maximum playercount, outside of which a
   warning will be generated.  If omitted, playercounts greater than 18
   will generate a warning.},

	default => ':18',
);

$p->add_arg(
	spec => 'critical|c=s',
	help => 
qq{-c, --critical=MIN:MAX
   Minimum and maximum playercount, outside of which a
   critical will be generated.  If omitted, playercounts greater than 19
   will generate a critical.},
	default => ':19',
);

$p->add_arg(
	spec => 'host|H=s',
	help => 
qq{-H, --host=address
   Address of host to monitor. If omitted, 127.0.0.1 will be used.},
	default => '127.0.0.1',
);

$p->add_arg(
	spec => 'port|P=i',
	help => 
qq{-P, --port=port
   Port of host to monitor. If omitted, 25575 will be used.},
	default => '25575',
);

$p->add_arg(
	spec => 'password|p=s',
	help => 
qq{-p, --password=password
   Required. Password for rcon.},
	required => 1,
);

$p->getopts;


my $rcon = Minecraft::RCON->new( 
	{
		password 	=>	$p->opts->password,
		address		=>	$p->opts->host,
		port		=>	$p->opts->port,
		strip_color	=>	1,
	}
	);
if ($rcon->connect){
	my ($players, $max);
	my $hidden = 0;
	my $response = $rcon->command('list');
	sleep 2; # Avoids a bug (race?) in MC-1.2.5/Bukkit-R4.0 that crashes servers.
	$rcon->disconnect;
        if ($response =~ /\//) {
                ($players, $hidden, $max) = ($response =~ /There are (\d+)\/(\d+) out of maximum (\d+) players online\./);
		$players += $hidden;
        } else {
                ($players, $max) = ($response =~ /There are (\d+) out of maximum (\d+) players online\./);
        }
	
	$p->add_perfdata( label => "players", value => $players );
	$p->add_perfdata( label => "hidden", value => $hidden );

	$p->nagios_exit(
		return_code => $p->check_threshold(check => $players, warning => $p->opts->warning, critical => $p->opts->critical), 
		message => "Players: $players\/$max Hidden: $hidden/$max",
	);
}	
else {
	sleep 2;
	$rcon->disconnect; # Avoids a bug (race?) in MC-1.2.5/Bukkit-R4.0 that crashes servers.
	$p->nagios_die( "check failed" );
}
