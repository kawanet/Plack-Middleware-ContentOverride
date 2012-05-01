use ExtUtils::MakeMaker;

my $opt = {
    NAME                =>  'Plack::Middleware::ContentOverride',
    VERSION_FROM        =>  'lib/Plack/Middleware/ContentOverride.pm',
    ABSTRACT_FROM       =>  'lib/Plack/Middleware/ContentOverride.pm',
    CONFIGURE_REQUIRES  =>  {
        'ExtUtils::MakeMaker'   => '6.55',
    },
    BUILD_REQUIRES      =>  {
        'HTTP::Request'         => '0',
        'Plack::Test'           => '0',
        'Test::More'            => '0',
        'URI'                   => '0',
    },
    PREREQ_PM           =>  {
        'Carp'                  => '0',
        'IO::File'              => '0',
        'Plack'                 => '0.9948',
    },
    AUTHOR              =>  'Yusuke Kawasaki',
    LICENSE             =>  'perl',
};

WriteMakefile( %$opt );
