# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################



use Test::More tests => 12;

BEGIN { use_ok( 'WWW::Odeon', () ); }

ok(1, "Testing module WWW::Odeon Version $WWW::Odeon::VERSION");

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my $odeon = new WWW::Odeon;
ok( 1, 'Object loaded' );

$odeon->cache_time( 5 );
is( $odeon->cache_time, 5, 'Cache time set/retrieved OK' );
is( $odeon->{_cache_secs}, 300, 'Internal cache time set OK' );

my @regions = sort @{$odeon->regions};
my @expected = qw( Central_London Channel_Islands Greater_London 
		Midlands North_East_England North_West_England 
		Scotland South_East_England South_West_England Wales);
ok( eq_array(\@expected, \@regions), 'Regions data retrieved as expected' );
# If we do this again we should hit the cache
@regions = ();
@regions = sort @{$odeon->regions};
is( $odeon->cached(), 1, 'Retrieved region data from cache OK' );
ok( eq_array(\@expected, \@regions), 'Cached data matches expectations' );

my @necinemas = sort @{$odeon->cinemas('North East England')};
# the space after Darlington in the following list is deliberate
@expected = ( 'Barnsley', 'Darlington ', 'Doncaster', 'Grimsby',
		'Harrogate', 'Hull', 'Leeds Bradford',
		'Newcastle Upon Tyne', 'Sheffield', 'York' );
ok( eq_array(\@expected, \@necinemas), 'Cinema data retrieved as expected' );
isnt( $odeon->cached(), 1, 'First cinema retrieval not cached' );
# and once more, to check we got cached data
@necinemas = ();
@necinemas = sort @{$odeon->cinemas('North East England')};
is ( $odeon->cached(), 1, 'Cinemas data retrieved OK from cache' );
ok( eq_array(\@expected, \@necinemas), 'Cached data matches expectations' );
