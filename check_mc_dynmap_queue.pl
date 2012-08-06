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
Bukkit/Minecraft server, run the \'/dynmap stats\' command, parses the
result, and returns the server\'s triggered update queue size for monitoring
with Nagios.  This plugin assumes that \'/dynmap stats\' is provided by the
Dynmap plugin, available at:

http://dev.bukkit.org/server-mods/dynmap/', 

	extra => "

THRESHOLDs for -w and -c are specified according to the standard Nagios range
format, documented here on the Nagios plug-in development guidelines page:

http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT

This range format is counter-intuitive, so please be sure to read the document
carefully, and pay particular attention to Table 3: Example Ranges. 


  Threshold example:

  Warn when queuesize >80,000 and critical when queuesize > 100,000:

  $PROGNAME -w ~:80000 -c ~:100000
  "
);

$p->add_arg(
	spec => 'warning|w=s',
	help => 
qq{-w, --warning=MIN:MAX
   Minimum and maximum queuesize, outside of which a
   warning will be generated.  If omitted, queuesize greater
   than 80,000 will generate a warning.},

	default => '~:80000',
);

$p->add_arg(
	spec => 'critical|c=s',
	help => 
qq{-c, --critical=MIN:MAX
   Minimum and maximum tickrate, outside of which a
   critical will be generated.  If omitted, queuesize greater
   than 100,000 will generate a critical.},
	default => '~:100000',
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
	my $response = $rcon->command('dynmap stats');
	my $queue = ($response =~ /Triggered update queue size: (\d+)/)[0];
	$rcon->disconnect();
	$p->add_perfdata( label => "queuesize", value => $queue );
	$p->nagios_exit(
		return_code => $p->check_threshold(check => $queue, warning => $p->opts->warning, critical => $p->opts->critical), 
		message => "Queue Size: $queue tiles",
	);
}	
else {
	$rcon->disconnect();
	$p->nagios_die( "check failed" );
}
