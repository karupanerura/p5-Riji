package Riji::Model::Atom;
use strict;
use warnings;
use utf8;

use Time::Piece;
use URI::tag;
use XML::FeedPP;
use Riji::Model::Entry;

use Mouse;

has setting => (
    is       => 'ro',
    isa      => 'Riji::Model::BlogSetting',
    required => 1,
    handles  => [qw/base_dir fqdn author title mkdn_dir url_root mkdn_path repo/],
);

no Mouse;

sub entries {
    my $self = shift;

    $self->{entries} ||= do {
        my @entries;
        for my $file ( grep { -f -r $_ && $_ =~ /\.md$/ } $self->mkdn_path->children ){
            my $path = $file->relative($self->mkdn_path);
            my $entry = Riji::Model::Entry->new(
                file     => $path,
                setting  => $self->setting,
            );

            my $entry_path = $file->basename;
            $entry_path =~ s/\.md$//;
            $entry_path = "entry/$entry_path";
            my $url = $self->url_root . $entry_path . '.html';
            my $tag_uri = URI->new('tag:');
            $tag_uri->authority($self->fqdn);
            $tag_uri->date(localtime($entry->file_history->last_modified_at)->strftime('%Y-%m-%d'));
            $tag_uri->specific(join('-',split(m{/},$entry_path)));

            push @entries, {
                title       => $entry->title,
                description => \$entry->body_as_html, #pass scalar ref for CDATA
                pubDate     => $entry->last_modified_at,
                author      => $entry->created_by,
                guid        => $tag_uri->as_string,
                published   => $entry->created_at,
                link        => $url,
            } unless $entry->headers('draft');
        }
        \@entries;
    };
}

sub feed {
    my $self = shift;

    my $last_modified_at = $self->repo->file_history($self->mkdn_dir)->last_modified_at;
    my $tag_uri = URI->new('tag:');
    $tag_uri->authority($self->fqdn);
    $tag_uri->date(gmtime($last_modified_at)->strftime('%Y-%m-%d'));
    my $feed = XML::FeedPP::Atom::Atom10->new(
        link    => $self->url_root,
        author  => $self->author,
        title   => $self->title,
        pubDate => $last_modified_at,
        id      => $tag_uri->as_string,
    );
    $feed->add_item(%$_) for @{ $self->entries };
    $feed->sort_item;

    $feed;
}

1;
