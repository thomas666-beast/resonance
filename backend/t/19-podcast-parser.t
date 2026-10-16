use Mojo::Base -strict;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/lib", "$FindBin::Bin/../lib";
use Resonance::Podcast::Parser qw(parse_feed);

my $fixture = "$FindBin::Bin/podcast-fixture.xml";
open my $fh, '<:raw', $fixture or die "Cannot open $fixture: $!";
my $xml = do { local $/; <$fh> };
close $fh;

my $feed = parse_feed($xml);

is $feed->{format},      'rss',           'format detected';
is $feed->{title},       'Test Podcast',  'channel title';
is $feed->{description}, 'A minimal test feed for Resonance.', 'channel description';
is $feed->{website_url}, 'https://example.com/podcast', 'channel link';
is $feed->{image_url},   'https://example.com/cover.jpg', 'channel image from itunes:image';
is $feed->{author},      'Jane Host',     'channel author';
is $feed->{language},    'en-us',         'channel language';

is scalar @{ $feed->{episodes} }, 2, 'exactly two episodes (item without enclosure skipped)';

my $ep1 = $feed->{episodes}[0];
is $ep1->{guid},          'ep-001',                    'episode guid';
is $ep1->{title},         'Episode One',               'episode title';
is $ep1->{audio_url},     'https://example.com/ep1.mp3','episode audio url';
is $ep1->{duration_sec},  5025,                        'duration parsed from 1:23:45';
is $ep1->{episode_number}, 1,                          'episode number';
is $ep1->{season_number},  1,                          'season number';
like $ep1->{published_at}, qr/^2024-01-01/,            'published_at parsed';

my $ep2 = $feed->{episodes}[1];
is $ep2->{guid},          'ep-002',                     'second episode guid';
is $ep2->{duration_sec},  1800,                         'duration parsed from plain seconds';
is $ep2->{audio_url},     'https://example.com/ep2.mp3','second episode audio url';

# Atom fixture
my $atom = <<'XML';
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom Test Show</title>
  <subtitle>An Atom podcast.</subtitle>
  <link rel="alternate" href="https://example.com/atom-show"/>
  <logo>https://example.com/atom-cover.png</logo>
  <author><name>Atom Host</name></author>
  <entry>
    <title>Atom Episode 1</title>
    <id>atom-001</id>
    <summary>The first atom episode.</summary>
    <published>2024-03-01T10:00:00Z</published>
    <link rel="enclosure" type="audio/mpeg" href="https://example.com/atom1.mp3"/>
  </entry>
</feed>
XML

my $atom_feed = parse_feed($atom);
is $atom_feed->{format},     'atom',                    'atom detected';
is $atom_feed->{title},      'Atom Test Show',          'atom title';
is $atom_feed->{website_url},'https://example.com/atom-show', 'atom link';
is $atom_feed->{image_url},  'https://example.com/atom-cover.png', 'atom logo';
is $atom_feed->{author},     'Atom Host',               'atom author';
is scalar @{ $atom_feed->{episodes} }, 1,               'atom has one episode';
is $atom_feed->{episodes}[0]{guid}, 'atom-001',         'atom episode guid';
is $atom_feed->{episodes}[0]{audio_url}, 'https://example.com/atom1.mp3',
                                                        'atom episode audio';

done_testing;
