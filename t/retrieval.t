# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# Author's note:
# This isn't the most robust set of tests imaginable; essentially this
# is testing little more than whether or not LWP::Simple can retrieve
# data from www.odeon.co.uk, and that the files served there haven't
# been altered so much that WWW::Odeon can no longer parse them.
#
# However given the nature of the module (fetching data from a remote
# host over which I have no control) I can't see any way to make the
# tests thorough, yet future-proof.

#########################


use Test::More tests => 5;

BEGIN { use_ok( 'WWW::Odeon' ); }

ok(1, "Testing module WWW::Odeon Version $WWW::Odeon::VERSION");

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my @regions = get_regions();
my $nregions = @regions;
ok( $nregions, "retrieved $nregions regions" );
# get cinemas in random region
my $rndregion = $regions[rand $nregions];
my @cinemas = get_cinemas( $rndregion );
my $ncinemas = @cinemas;
ok( $ncinemas, "retrieved $ncinemas cinemas from region $rndregion" );

# at the time of writing, www.odeon.co.uk was unable to provide film
# details for a few cinemas, including 'Bath (ABC)' and 'Allerton'.
# so if the region is SW or NW england, try to retrieve data for the
# cinema with index 1, for all others use index 0
my $idx = $rndregion =~ /West_England/ ? 1 : 0;
# get details from first cinema returned
my $details = get_details( $cinemas[$idx] );
ok( keys %$details, "retrieved details for cinema $cinemas[$idx]" );

