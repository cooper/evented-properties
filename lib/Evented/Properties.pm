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

our $VERSION = '0.40';
our $props   = $Evented::Object::props;

# Evented::Properties import subroutine.
sub import {
    my ($class, @opts) = @_;
    my $package = caller;
    
    # store Evented::Properties options.
    my $store = _prop_store($class);
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

# fetch the Evented::Properties section of a package store.
sub _prop_store { Evented::Object::_package_store(shift)->{EventedProperties} ||= {} }

# called by the anonymous lvalue subroutines.
sub get_lvalue : lvalue {
    my ($property, $eo) = @_;
    add_default_set_callback($eo);
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
sub add_default_set_callback {
    my $eo = shift;
    return if $eo->{$props}{eventedProperties}{has_set_cb};
    $eo->register_callback(set => \&_default_callback,
        name     => 'evented.properties.set',
        priority => 1000 # it's kinda important to set value first
    );
    $eo->{$props}{eventedProperties}{has_set_cb} = 1;
}

# default set callback.
sub  _default_callback { &__default_callback }
sub __default_callback {
    my ($fire, $prop_name, $old, $new) = @_;
    $fire->{new} = $new;
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
# I don't see a reason, at least currently, to fire these as events. perhaps there should
# be an option to enable such events with the possibility to modify what is returned.
# hmm, maybe. this could be a cool evented tie type of deal.
sub FETCH {
    my $prop = shift;
    return $prop->{value};
}

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
