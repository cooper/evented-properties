use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
    module_name         => 'Evented::Properties',
    dist_author         => 'Mitchell Cooper <cooper@cpan.org>',
    dist_abstract       => 'object property setters and getters for Evented::Object',
    requires            => {
        'perl'            => '5.010',
        'Evented::Object' => '0.3'
    },
    recommends          => {},
    build_requires      => {},
    license             => 'bsd',
    create_makefile_pl  => 'traditional',
    # create_license    => 1,
    # create_readme     => 1,
    dynamic_config      => 0,
    meta_merge          => {
        resources => {
            repository => 'https://github.com/cooper/evented-properties'
        }
    },
);

$build->create_build_script;
