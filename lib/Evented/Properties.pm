#
# Copyright (c) 2014, Mitchell Cooper
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
use parent 'Tie::Scalar';

use Carp;
use Scalar::Util qw(weaken blessed);

use Evented::Object;
use Evented::Object::Hax 'export_code';

our $VERSION = '0.41';
our $props   = $Evented::Object::props;

# Evented::Properties import subroutine.
sub import {
    my ($class, @opts) = @_;
    my $package = caller;
    
    # store Evented::Properties options.
    my $store = _prop_store($class);
    $store->{desired} = \@opts;
    
    # determine properties.
    # ex: use Evented::Properties qw(some_prop some_other), [my_prop => 'ro']
    # maybe I should do something like
    # ex: use Evented::Properties qw(some_prop some_other:ro)
    my (%props, $last_thing);
    foreach my $thing (@opts) {
        if    (!ref $thing)            { $props{ $thing      } = []                   }
        elsif ( ref $thing eq 'ARRAY') { $props{ $thing->[0] } = @$thing[1..$#$thing] }
    }
    
    # add each property.
    add_property($package, $_, %{ $props{$_} }) foreach keys %props;
    
    return 1;
}

# fetch the Evented::Properties section of a package store.
sub _prop_store { Evented::Object::_package_store(shift)->{EventedProperties} ||= {} }

# called by the anonymous lvalue subroutines.
sub get_lvalue : lvalue {
    my ($property, $eo) = @_;
    add_default_callbacks($eo);
    my $r = \($eo->{$props}{eventedProperties}{properties}{$property} //= undef);
    tie $$r, __PACKAGE__, $property, $eo if not tied $$r;
    return $$r;
}

# adds a property to a package.
sub add_property {
    my ($package, $property, %opts) = @_;

    # export the code with the lvalue attribute.
    export_code($package, $property, sub : lvalue { get_lvalue($property, @_) });
    attributes::->import($package, $package->can($property), 'lvalue');
    
    # store property info.
    my $store = _prop_store($package);
    $store->{properties}{$property} = \%opts;
    
    return 1;
}

# add the default set callback if not already existing.
# perhaps one day when there are subroutine callbacks, this could be injected into
# the Evented::Object smybol table so it does not have to be reproduced over and over.
sub add_default_callbacks {
    my $eo = shift;
    
    # default setter callback.
    if (!$eo->{$props}{eventedProperties}{has_set_cb}) {
        $eo->register_callback(set => \&_default_set_callback,
            name     => 'evented.properties.set',
            priority => 1000 # it's kinda important to set value first
        );
        $eo->{$props}{eventedProperties}{has_set_cb} = 1;
    }
    
    # default getter callback.
    if (!$eo->{$props}{eventedProperties}{has_get_cb}) {
        $eo->register_callback(get => \&_default_get_callback,
            name     => 'evented.properties.get',
            priority => 1000 # it's kinda important to fetch value first
        );
        $eo->{$props}{eventedProperties}{has_get_cb} = 1;
    }
    
    return 1;
}

sub _default_set_callback { &__default_set_callback }
sub _default_get_callback { &__default_get_callback }

# default set callback.
sub __default_set_callback {
    my ($fire, $prop_name, $old, $new) = @_;
    $fire->{new} = $new;
}

# default get callback.
sub __default_get_callback {
    my ($fire, $prop_name, $value) = @_;
    $fire->{value} = $value;
}

#################
### TIE MAGIC ###
#################

# create a new tie.
sub TIESCALAR {
    my ($class, $property, $eo) = @_;
    my $prop = bless {
        name  => $property,
        value => undef,
        eo    => $eo
    }, __PACKAGE__;
    weaken($prop->{eo});
    return $prop;
}

# fetch the value.
sub FETCH {
    my $prop = shift;
    
    # if an evented object is associated, fire the get events,
    # and use the ->{value} value.
    if (blessed $prop->{eo} && $prop->{eo}->isa('Evented::Object')) {
        my $fire = $prop->{eo}->fire_events_together(
            [ "get_$$prop{name}" =>                $prop->{value} ],
            [ get                => $prop->{name}, $prop->{value} ]
        );
        return $fire->{value};
    }
    
    # otherwise, fall back to the actual value.
    return $prop->{value};
    
}

# store a value.
sub STORE {
    my ($prop, $new) = @_;
    my $old = $prop->{value};
    
    # if an evented object is associated, fire the set events,
    # and use the ->{new} value.
    if (blessed $prop->{eo} && $prop->{eo}->isa('Evented::Object')) {
        my $fire = $prop->{eo}->fire_events_together(
            [ "set_$$prop{name}" =>                $old, $new ],
            [ set                => $prop->{name}, $old, $new ]
        );
        return $prop->{value} = $fire->{new};
    }
    
    # otherwise, fall back to just assigning directly.
    return $prop->{value} = $new;
    
}

1;
