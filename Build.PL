use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'WWW::Proxy4FreeCom',
    license             => 'perl',
    dist_author         => 'Zoffix <zoffix@cpan.org>',
    dist_version_from   => 'lib/WWW/Proxy4FreeCom.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'Carp'                     => 1.04,
        'URI'                      => 1.35,
        'LWP::UserAgent'           => 2.036,
        'Mojo::DOM'                => 0,
        'Class::Accessor::Grouped' => 0,
        'perl'                     => '5.006',
    },
    configure_requires => { 'Module::Build' => 0 },
    add_to_cleanup      => [ 'WWW-Proxy4FreeCom-*' ],
    create_makefile_pl => 'traditional',
);
if ( $ENV{RELEASE_TESTING} ) {
    system('pod2text lib/WWW/Proxy4FreeCom.pm > README');
}

$builder->create_build_script();
