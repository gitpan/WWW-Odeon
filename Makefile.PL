use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'WWW::Odeon',
    'VERSION_FROM'	=> 'Odeon.pm', # finds $VERSION
    'PREREQ_PM'		=> { LWP::Simple => 1.00, Test::More => 0.30 },
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Odeon.pm', # retrieve abstract from module
       AUTHOR     => 'Iain Tatch <iaint@cpan.org>') : ()),
);
