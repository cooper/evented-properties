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
use Scalar::Util 'blessed';
use Evented::Object;

our $VERSION = 0.3;

# Evented::Properties import subroutine.
sub import {
    my ($class, @opts) = @_;
    my $package = caller;
    
    # store Evented::Properties options.
    my $store = Evented::Object::_package_store($package)->{EventedProperties} ||= {};
    $store->{desired} = \@opts;
    
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

# safely fire an event.
sub safe_fire {
    my $obj = shift;
    return if !blessed $obj || !$obj->isa('Evented::Object');
    return $obj->fire_event(@_);
}

# %opts = (
#     readonly => undef or 1,
#     getter   => CODE or 'default',
#     setter   => CODE or sub { return } if readonly or 'default'
# )

# adds a property to a package.
sub add_property {
    my ($package, $property, %opts) = @_;
    
    # determine the getter.
    if (defined $opts{getter} and !ref $opts{getter} || ref $opts{getter} ne 'CODE') {
        carp "Evented property '$property' for '$package' provided a non-code getter.";
        return;
    }
    
    # default getter.
    elsif (!defined $opts{getter}) {
        $opts{getter} = sub {
            my $obj = shift;
            return $obj->{$property};
        };
    }

    # determine the setter.
    if (defined $opts{setter} and !ref $opts{setter} || ref $opts{setter} ne 'CODE') {
        carp "Evented property '$property' for '$package' provided a non-code setter.";
        return;
    }
    
    # default setter.
    elsif (!defined $opts{setter}) {
        $opts{setter} = sub {
            my ($obj, $val) = @_;
            $obj->{$property} = $val;
        }
    }
    
    # for readonly properties, return undef on setters.
    if ($opts{readonly}) {
        $opts{setter} = sub {
            carp "Setter called on readonly evented property '$property' for '$package'";
            return;
        };
    }

    # export getter.
    export_code($package, $property, sub {
        my $obj = @_;
        safe_fire($obj, "get_$property"); # XXX: when would this be useful?
        $opts{getter}(@_);
    });
    
    # export setter.
    export_code($package, "set_$property", sub {
        my ($obj, $new) = @_;
        safe_fire($obj, "set_$property" => $obj->can($property) ? $obj->$property : undef, $new);
        $opts{setter}(@_);
    });

    # store property info.
    my $store = Evented::Object::_package_store($package)->{EventedProperties} ||= {};
    $store->{properties}{$property} = \%opts;
    
    return 1;
}

1;
