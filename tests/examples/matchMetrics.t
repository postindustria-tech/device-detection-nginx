#!/usr/bin/perl

# (C) Sergey Kandaurov
# (C) Maxim Dounin
# (C) Nginx, Inc.

# Tests for 51Degrees Hash Trie module.

###############################################################################

use warnings;
use strict;
use File::Temp qw/ tempdir /;
use Test::More;
use File::Copy;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib '../nginx-tests/lib';
use Test::Nginx;
use URI::Escape;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

sub read_example($) {
	my ($name) = @_;
	open my $fh, '<', '../../examples/hash/' . $name or die "Can't open file $name: $!";
	read $fh, my $content, -s $fh;
	close $fh;

	return $content;
}

my $t = Test::Nginx->new()->has(qw/http/)->plan(3);

my $t_file = read_example('matchMetrics.conf');
# Remove documentation block
$t_file =~ s/\/\*\*.+\*\//''/gmse;
# Replace variable place holders
$t_file =~ s/%%DAEMON_MODE%%/'off'/gmse;
$t_file =~ s/%%MODULE_PATH%%/$ENV{TEST_MODULE_PATH}/gmse;
$t_file =~ s/%%FILE_PATH%%/$ENV{TEST_FILE_PATH}/gmse;
$t->write_file_expand('nginx.conf', $t_file);

$t->write_file('metrics', '');

$t->run();

sub get_with_ua {
	my ($uri, $ua) = @_;
	return http(<<EOF);
HEAD $uri HTTP/1.1
Host: localhost
Connection: close
User-Agent: $ua

EOF
}

###############################################################################
# Constants.
###############################################################################

my $mobileUserAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 7_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D167 Safari/9537.53';

###############################################################################
# Test matchMetrics.conf example.
###############################################################################

my $r = get_with_ua('/metrics', $mobileUserAgent);
like($r, qr/x-metrics: \d+,\d+,PREDICTIVE,\d+/, 'Match metrics');
like($r, qr/x-user-agents: (?!NA$).*/, 'Matched user agents string');
like($r, qr/x-device-id: \d+-\d+-\d+-\d+/, 'Device ID');

###############################################################################

