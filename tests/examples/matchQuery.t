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

my $t = Test::Nginx->new()->has(qw/http/)->plan(2);

my $t_file = read_example('matchQuery.conf');
# Remove documentation block
$t_file =~ s/\/\*\*.+\*\//''/gmse;
# Remove all variable place holders
$t_file =~ s/%%DAEMON_MODE%%/'off'/gmse;
$t_file =~ s/%%MODULE_PATH%%/$ENV{TEST_MODULE_PATH}/gmse;
$t_file =~ s/%%FILE_PATH%%/$ENV{TEST_FILE_PATH}/gmse;
$t->write_file_expand('nginx.conf', $t_file);

$t->write_file('query', '');

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
my $desktopUserAgent = 'Mozilla/5.0 (Windows NT 6.3; WOW64; rv:41.0) Gecko/20100101 Firefox/41.0';

###############################################################################
# Test matchQuery.conf example.
###############################################################################

my $r = get_with_ua('/query?User-Agent='.uri_escape($mobileUserAgent), $desktopUserAgent);
like($r, qr/x-mobile-single: True/, 'Mobile match (single)');
like($r, qr/x-mobile-all: True/, 'Mobile match (all)');

###############################################################################

