package Plack::Middleware::ContentOverride;
use strict;
use warnings;
use parent 'Plack::Middleware';

use Carp;
use IO::File;
use Plack::Request;
use Plack::Util::Accessor qw( payload content_type );
use Plack::TempBuffer;

our $VERSION      = '0.01';
our $PARAM        = 'payload';
our $CONTENT_TYPE = 'application/octet-stream';

sub call {
    my $self = shift;
    my $env  = shift;
    my $req  = Plack::Request->new($env);

    my $save = $req->parameters; # keep parameters
    my $key  = $self->payload || $PARAM;
    my $val  = $req->param($key);
    my $type = $self->content_type || $CONTENT_TYPE;

    if (defined $val) {
        # application/x-www-form-urlencoded
        my $buffer = Plack::TempBuffer->new;
        $buffer->print($val);
        $env->{'psgi.input'}   = $buffer->rewind;
        $env->{CONTENT_LENGTH} = $buffer->size;
        $env->{CONTENT_TYPE}   = $type;
    } elsif (my $upload = $req->upload($key)) {
        # multipart/form-data
        my $path = $upload->path;
        $env->{'psgi.input'}   = IO::File->new($path);
        $env->{CONTENT_LENGTH} = $upload->size;
        my $header = $upload->{headers} || {};
        $env->{CONTENT_TYPE} = $header->{'content-type'} || $type;
        foreach my $k (keys %$header) {
            $req->header($k => $header->{$k});
        }
    } else {
        my $reqtype = $req->content_type || '';
        $reqtype =~ s/^\s+//s;
        $reqtype =~ s/[\s;].*$//s;
        $reqtype = lc($reqtype);
        if ($reqtype eq '' ||
            $reqtype eq 'application/x-www-form-urlencoded' ||
            $reqtype eq 'multipart/form-data') {
            # empty content
            $env->{'psgi.input'}   = Plack::TempBuffer->new->rewind;
            $env->{CONTENT_LENGTH} = 0;
            $env->{CONTENT_TYPE}   = $type;
        } else {
            # through current content
        }
    }

    delete $env->{'psgix.input.buffered'};    # boolean
    delete $env->{'plack.request.body'};      # body parameters
    delete $env->{'plack.request.http.body'}; # HTTP::Body
    delete $env->{'plack.request.upload'};    # Plack::Request::Upload
    # delete $env->{'plack.request.merged'};  # head+body parameters
    $env->{'plack.request.merged'} = $save;

    $self->app->($env);
}

1;
__END__

=head1 NAME

Plack::Middleware::ContentOverride - Override Request Content Body by File Uploading or Query Parameter

=head1 SYNOPSIS

In your Plack app:

    use Plack::Request;

    my $app = sub {
        my $env  = shift;
        my $req  = Plack::Request->new($env);
        my $type = $req->content_type;
        my $body = $req->content;
        ...;
    }

    use Plack::Builder;

    builder {
        enable 'ContentOverride';
        $app;
    };

Payload as an uploaded file overrides the request content body:

    <form method="POST" enctype="multipart/form-data" action="...">
        <input type="file" name="payload">
    </form>
    
Payload as a query parameter overrides the request content body:

    <form enctype="application/x-www-form-urlencoded" action="...">
        <textarea name="payload"></textarea>
    </form>

=head1 DESCRIPTION

This allows a payload sent from a HTML form
to override C<Plack>'s request content body.
This would help you to run a RESTful app
through traditional HTML forms.

A couple of payload styles are available:
1. file uploading and 2. query parameter.

=head2 File Uploading

For an app which receives a binary content of JPEG, PNG, etc.
including a larger content, 
use C<method="POST"> and C<enctype="multipart/form-data">
to perform a file uploading.

=head2 Query Parameter

For an app which receives a text content of JSON, XML, etc.,
C<textarea> element would work fine.

=head1 CONFIGURATION

This middleware accepts the following configuration keys.

    enable 'ContentOverride', payload => 'body', content_type => 'application/xml';

=head2 payload

This specifies a request query parameter which contains a new content body.
Default name is C<payload>.

    enable 'ContentOverride', payload => 'payload'; # default

=head2 content_type

This specifies a new content type.
Default type is C<application/octet-stream>.

    enable 'ContentOverride', content_type => 'application/octet-stream'; # default

=head1 AUTHOR

Yusuke Kawasaki http://www.kawa.net/

=head1 COPYRIGHT

The following copyright notice applies to all the files provided in
this distribution, including binary files, unless explicitly noted
otherwise.

Copyright 2012 Yusuke Kawasaki

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Plack::Middleware::MethodOverride> - Override REST methods to Plack apps via POST  

L<Catalyst::Action::DeserializeMultiPart> - Deserialize Data in a Multipart Request

=cut

