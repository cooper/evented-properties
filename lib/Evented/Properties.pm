#
# Copyright (c) 2013, Mitchell Cooper
#
# Evented::Properties: object property getters and setters for Evented::Object
#
# Evented::Properties can be found in its latest version at
# https://github.com/cooper/evented-properties.
#
#
package Evented::Properties;

use warnings;
use strict;
use utf8;
use 5.010;

use Carp;

our $VERSION = 0.1;
our %p;       # %p = package options

# Evented::Properties import subroutine.
sub import {
    my ($class, @opts) = @_;
    my $package = caller;
    
    # store Evented::Properties options.
    $p{$package}{desired} = \@opts;
    
    # determine properties.
    my (%props, $last_thing);
    foreach my $thing (@opts) {
        if (ref $thing && ref $thing eq 'HASH') { $props{$last_thing} = $thing }
        else                                    { $props{$thing}      = {}     }
        $last_thing = $thing;
    }
    
    # add each property.
    add_property($package, $_, %{ $props{$_} }) foreach keys %props;
    
    return 1;
}

# export a subroutine.
# export_code('My::Package', 'my_sub', \&_my_sub)
sub export_code {
    my ($package, $sub_name, $code) = @_;
    no strict 'refs';
    *{"${package}::$sub_name"} = $code;
}

# %opts = (
#     readonly => 1,
#     get_code => CODE or 'default',
#     set_code => CODE or sub { return } if readonly or 'default'
# )

# adds a property to a package.
sub add_property {
    my ($package, $property, %opts) = @_;
    
    # determine the getter.
    if (defined $opts{get_code} and !ref $opts{get_code} || ref $opts{get_code} ne 'CODE') {
        carp "Evented property '$property' for '$package' provided a non-code getter.";
        return;
    }
    
    # default getter.
    elsif (!defined $opts{get_code}) {
        $opts{get_code} = sub {
            my $obj = shift;
            return $obj->{$property};
        };
    }

    # determine the setter.
    if (defined $opts{set_code} and !ref $opts{set_code} || ref $opts{set_code} ne 'CODE') {
        carp "Evented property '$property' for '$package' provided a non-code setter.";
        return;
    }
    
    # default setter.
    elsif (!defined $opts{set_code}) {
        $opts{set_code} = sub {
            my ($obj, $val) = @_;
            $obj->{$property} = $val;
        }
    }
    
    # for readonly properties, return undef on setters.
    if ($opts{readonly}) {
        $opts{set_code} = sub {
            carp "Setter called on readonly evented property '$property' for '$package'";
            return;
        };
    }

    # export getter and setter.
    export_code($package, $property,       $opts{get_code});
    export_code($package, "set_$property", $opts{set_code});

    # store property info.
    $p{$package}{properties}{$property} = \%opts;
    
    return 1;
}

1;
