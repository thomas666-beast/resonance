package Resonance::Podcast::Parser;
use Mojo::Base -strict, -signatures;
use Exporter 'import';

our @EXPORT_OK = qw(parse_feed);

use XML::LibXML;
use XML::LibXML::XPathContext;
use Time::Piece ();

# ── helpers ──────────────────────────────────────────────

sub _text ($node = undef) {
    return undef unless $node;
    my $s = $node->textContent;
    return undef unless defined $s;
    $s =~ s/^\s+|\s+$//g;
    return length $s ? $s : undef;
}

# First matching node using a registered-namespace XPathContext.
# FIX: always returns exactly ONE scalar (a node or undef). The old version
# returned an empty list when nothing matched, so `_text(_find(...))` became
# `_text()` with zero args and died under signatures.
sub _find ($xpc, $node, $xpath) {
    return undef unless $node;
    my ($first) = $xpc->findnodes($xpath, $node);
    return $first;
}

sub _first_text ($xpc, $node, $xpath) {
    return _text(scalar _find($xpc, $node, $xpath));
}

sub _iso_time ($str) {
    return undef unless defined $str && length $str;
    $str =~ s/^\s+|\s+$//g;

    for my $fmt ('%a, %d %b %Y %H:%M:%S %z',
                 '%a, %d %b %Y %H:%M:%S %Z',
                 '%a, %d %b %Y %H:%M %z',
                 '%Y-%m-%dT%H:%M:%S%z',
                 '%Y-%m-%dT%H:%M:%SZ',
                 '%Y-%m-%d') {
        my $t = eval { Time::Piece->strptime($str, $fmt) };
        return $t->datetime if $t;
    }
    return undef;
}

sub _parse_duration ($str) {
    return undef unless defined $str && length $str;
    $str =~ s/^\s+|\s+$//g;

    return 0 + $str                 if $str =~ /^\d+$/;
    return $1 * 3600 + $2 * 60 + $3 if $str =~ /^(\d+):(\d+):(\d+)$/;
    return $1 * 60 + $2             if $str =~ /^(\d+):(\d+)$/;
    return undef;
}

# ── main parser ──────────────────────────────────────────

sub parse_feed ($xml_string) {
    # FIX: do not decode. libxml2 should read raw bytes and honour the
    # encoding declared in the XML prolog. If the caller handed us a
    # character string, turn it back into UTF-8 bytes.
    utf8::encode($xml_string) if utf8::is_utf8($xml_string);

    # load_xml throws on malformed XML, so no `or die` needed.
    # The extra options protect against XXE / network fetches in
    # untrusted feeds.
    my $dom = XML::LibXML->load_xml(
        string          => $xml_string,
        no_blanks       => 1,
        no_network      => 1,
        load_ext_dtd    => 0,
        expand_entities => 0,
    );

    my $xpc = XML::LibXML::XPathContext->new($dom);
    $xpc->registerNs('itunes',  'http://www.itunes.com/dtds/podcast-1.0.dtd');
    $xpc->registerNs('content', 'http://purl.org/rss/1.0/modules/content/');
    $xpc->registerNs('podcast', 'https://podcastindex.org/namespace/1.0');
    $xpc->registerNs('atom',    'http://www.w3.org/2005/Atom');

    my $root = $dom->documentElement
        or die "No root element\n";
    my $root_name = $root->localname // '';

    return _parse_atom($xpc, $root) if $root_name eq 'feed';
    return _parse_rss($xpc, $root);
}

# ── RSS 2.0 (+ iTunes) ───────────────────────────────────

sub _parse_rss ($xpc, $root) {
    my $channel = _find($xpc, $root, 'channel')
        or die "RSS feed has no <channel>\n";

    my $title  = _first_text($xpc, $channel, 'title');
    my $desc   = _first_text($xpc, $channel, 'description')
              // _first_text($xpc, $channel, 'itunes:summary');
    my $link   = _first_text($xpc, $channel, 'link');
    my $lang   = _first_text($xpc, $channel, 'language');
    my $author = _first_text($xpc, $channel, 'itunes:author')
              // _first_text($xpc, $channel, 'managingEditor');

    my $image_url;
    my $itunes_image = _find($xpc, $channel, 'itunes:image');
    $image_url = $itunes_image->getAttribute('href') if $itunes_image;

    if (!$image_url) {
        my $podcast_img = _find($xpc, $channel, 'podcast:image');
        $image_url = $podcast_img->getAttribute('href') if $podcast_img;
    }

    if (!$image_url) {
        $image_url = _first_text($xpc, $channel, 'image/url');
    }

    my $itunes_id;
    my $apple_id = _find($xpc, $channel, 'podcast:id');
    if ($apple_id) {
        my $text = _text($apple_id);
        $itunes_id = $text if defined $text && $text =~ /^\d+$/;
    }

    my @episodes;
    for my $item ($xpc->findnodes('item', $channel)) {
        my $ep = _parse_rss_item($xpc, $item);
        push @episodes, $ep if $ep;
    }

    return {
        format      => 'rss',
        title       => $title,
        description => $desc,
        website_url => $link,
        image_url   => $image_url,
        author      => $author,
        language    => $lang,
        itunes_id   => $itunes_id,
        episodes    => \@episodes,
    };
}

sub _parse_rss_item ($xpc, $item) {
    my $title = _first_text($xpc, $item, 'title');
    my $guid  = _first_text($xpc, $item, 'guid');
    my $desc  = _first_text($xpc, $item, 'description')
             // _first_text($xpc, $item, 'itunes:summary')
             // _first_text($xpc, $item, 'content:encoded');
    my $pub   = _iso_time(_first_text($xpc, $item, 'pubDate'));
    my $dur   = _parse_duration(_first_text($xpc, $item, 'itunes:duration'));

    my $enclosure = _find($xpc, $item, 'enclosure');
    my $audio_url;
    if ($enclosure) {
        my $type = $enclosure->getAttribute('type') // '';
        # FIX: also accept video enclosures (video podcasts)
        if ($type =~ m{^(?:audio|video)/} || !length $type) {
            $audio_url = $enclosure->getAttribute('url');
        }
    }

    my $ep_num = _first_text($xpc, $item, 'itunes:episode');
    my $se_num = _first_text($xpc, $item, 'itunes:season');

    my $image_url;
    my $itunes_img = _find($xpc, $item, 'itunes:image');
    $image_url = $itunes_img->getAttribute('href') if $itunes_img;

    return undef unless defined $audio_url && length $audio_url;
    $guid ||= $audio_url;

    return {
        guid           => $guid,
        title          => $title // '(untitled)',
        description    => $desc,
        audio_url      => $audio_url,
        duration_sec   => $dur,
        published_at   => $pub,
        image_url      => $image_url,
        episode_number => (defined $ep_num && $ep_num =~ /^\d+$/) ? 0 + $ep_num : undef,
        season_number  => (defined $se_num && $se_num =~ /^\d+$/) ? 0 + $se_num : undef,
    };
}

# ── Atom ─────────────────────────────────────────────────

sub _parse_atom ($xpc, $root) {
    my $title = _first_text($xpc, $root, 'atom:title')
             // _first_text($xpc, $root, 'title');
    my $desc  = _first_text($xpc, $root, 'atom:subtitle')
             // _first_text($xpc, $root, 'subtitle');
    my $lang  = $root->getAttribute('xml:lang');

    my $link;
    for my $l ($xpc->findnodes('atom:link | link', $root)) {
        my $rel = $l->getAttribute('rel') // '';
        next unless $rel eq 'alternate' || $rel eq '';
        $link = $l->getAttribute('href');
        last if $link;
    }

    my $image_url = _first_text($xpc, $root, 'atom:logo')
                 // _first_text($xpc, $root, 'logo');
    my $author    = _first_text($xpc, $root, 'atom:author/atom:name')
                 // _first_text($xpc, $root, 'author/name');

    my @episodes;
    for my $entry ($xpc->findnodes('atom:entry | entry', $root)) {
        my $ep = _parse_atom_entry($xpc, $entry);
        push @episodes, $ep if $ep;
    }

    return {
        format      => 'atom',
        title       => $title,
        description => $desc,
        website_url => $link,
        image_url   => $image_url,
        author      => $author,
        language    => $lang,
        itunes_id   => undef,
        episodes    => \@episodes,
    };
}

sub _parse_atom_entry ($xpc, $entry) {
    my $title = _first_text($xpc, $entry, 'atom:title')
             // _first_text($xpc, $entry, 'title');
    my $guid  = _first_text($xpc, $entry, 'atom:id')
             // _first_text($xpc, $entry, 'id');
    my $desc  = _first_text($xpc, $entry, 'atom:summary')
             // _first_text($xpc, $entry, 'atom:content')
             // _first_text($xpc, $entry, 'summary');
    my $pub   = _iso_time(
        _first_text($xpc, $entry, 'atom:published')
        // _first_text($xpc, $entry, 'atom:updated')
        // _first_text($xpc, $entry, 'published')
    );

    my $audio_url;
    for my $l ($xpc->findnodes('atom:link | link', $entry)) {
        my $rel = $l->getAttribute('rel') // '';
        next unless $rel eq 'enclosure';
        $audio_url = $l->getAttribute('href');
        last if $audio_url;
    }

    return undef unless defined $audio_url && length $audio_url;
    $guid ||= $audio_url;

    return {
        guid           => $guid,
        title          => $title // '(untitled)',
        description    => $desc,
        audio_url      => $audio_url,
        duration_sec   => undef,
        published_at   => $pub,
        image_url      => undef,
        episode_number => undef,
        season_number  => undef,
    };
}

1;
