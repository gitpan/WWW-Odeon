# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################



use Test::More tests => 3;

BEGIN { use_ok( 'WWW::Odeon' ); }

ok(1, "Testing module WWW::Odeon Version $WWW::Odeon::VERSION");

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.


# this tests some of the internal algorithms
my $csv = q+"one","two, three","four, five, six","seven","eighth'thing"+;
my @expect = ( 'one', 'two, three', 'four, five, six', 'seven', "eighth'thing" );
my @sep = WWW::Odeon::_get_items( $csv );
is_deeply( \@sep, \@expect, 'Split CSV text string' );

