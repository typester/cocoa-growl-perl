package Cocoa::Growl;
use strict;
use warnings;
use parent 'Exporter';

use XSLoader;
use URI;

our $VERSION = '0.01';

our @EXPORT_OK   = qw(growl_installed growl_running growl_register growl_notify);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

use File::ShareDir ();
use File::Spec;

our $FRAMEWORK_DIR = do {
    (my $dist = __PACKAGE__) =~ s/::/-/g;
    File::Spec->catfile(File::ShareDir::dist_dir($dist), 'Growl.framework');
};

XSLoader::load __PACKAGE__, $VERSION;

sub growl_notify {
    my %info = @_;

    my $title       = $info{title} || '';
    my $description = $info{description} || '';
    my $notifName   = $info{notificationName} || '';

    my $on_click   = $info{onClick};
    my $on_timeout = $info{onTimeout};

    _growl_notify($title, $description, $notifName, undef, $on_click, $on_timeout);
}

sub growl_register {
    my %info = @_;

    my $appName  = $info{appName} || __PACKAGE__;
    my $appIcon  = $info{appIcon};
    my $all      = $info{allNotifications};
    my $defaults = $info{defaultNotifications} || $all;

    if ($appIcon) {
        my $uri = URI->new($appIcon);
        $uri->scheme or do { $uri->scheme('file'); $uri->host('') };
        $appIcon = $uri->as_string;
    }

    _growl_register($appName, $all, $defaults, $appIcon);
}

1;

__END__

=head1 NAME

Cocoa::Growl - Module abstract (<= 44 characters) goes here

=head1 SYNOPSIS

    use Cocoa::Growl ':all';
    
    my $installed = growl_installed(); # true if Growl is installed.
    my $running   = growl_running();   # true if Growl is running.
    
    # register notifications
    growl_register(
        appName          => 'My growl script',
        allNotifications => [qw(Notification1 Notification2)],
    );
    
    # show growl notification
    growl_notify(
        notificationName => 'Notification1',
        title            => 'Hello!',
        description      => 'Growl world!',
    );

=head1 DESCRIPTION

Stub documentation for this module was created by ExtUtils::ModuleMaker.
It looks like the author of the extension was negligent enough
to leave the stub unedited.

Blah blah blah.

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009 by KAYAC Inc.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
