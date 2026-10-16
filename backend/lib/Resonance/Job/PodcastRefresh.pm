package Resonance::Job::PodcastRefresh;
use Mojo::Base -strict, -signatures;

use Mojo::UserAgent;
use Resonance::Podcast::Parser qw(parse_feed);
use Mojo::JSON qw(encode_json);

my $UA_STRING = 'Mozilla/5.0 (compatible; Resonance/0.01)';

sub register ($minion) {
    $minion->add_task(podcast_refresh => sub ($job, $feed_id) {
        my $app   = $job->app;
        my $pg    = $app->pg;
        my $redis = $app->redis;

        my $feed = $pg->db->query(
            'SELECT id, feed_url FROM podcast_feeds WHERE id = ?',
            $feed_id,
        )->hash;

        unless ($feed) {
            $job->fail("feed $feed_id not found");
            return;
        }

        $app->log->info("Podcast: refreshing feed $feed_id ($feed->{feed_url})");

        my $ua = Mojo::UserAgent->new(
            connect_timeout    => 10,
            inactivity_timeout => 30,
            max_redirects      => 5,
        );
        $ua->transactor->name($UA_STRING);

        my $tx = $ua->get($feed->{feed_url});

        if ($tx->error) {
            my $err = $tx->error->{message} // 'unknown error';
            $pg->db->query(
                'UPDATE podcast_feeds SET last_error = ?, updated_at = now() WHERE id = ?',
                $err, $feed_id,
            );
            $app->log->warn("Podcast: refresh failed: $err");
            $job->finish({ ok => 0, error => $err });
            return;
        }

        my $body = $tx->res->body;
        unless (defined $body && length $body) {
            $pg->db->query(
                'UPDATE podcast_feeds SET last_error = ?, updated_at = now() WHERE id = ?',
                'empty response', $feed_id,
            );
            $job->finish({ ok => 0, error => 'empty response' });
            return;
        }

        my $parsed = eval { parse_feed($body) };
        if (!$parsed) {
            my $err = $@ // 'parse failed';
            $err =~ s/\s+$//;
            $pg->db->query(
                'UPDATE podcast_feeds SET last_error = ?, updated_at = now() WHERE id = ?',
                $err, $feed_id,
            );
            $app->log->warn("Podcast: parse failed: $err");
            $job->finish({ ok => 0, error => $err });
            return;
        }

        my $db = $pg->db;
        $db->query('BEGIN');

        my ($inserted, $updated) = (0, 0);

        eval {
            $db->query(
                q{UPDATE podcast_feeds
                      SET title = ?, description = ?, website_url = ?,
                          image_url = ?, author = ?, language = ?,
                          itunes_id = COALESCE(?, itunes_id),
                          last_fetched_at = now(),
                          last_error = NULL,
                          updated_at = now()
                    WHERE id = ?},
                $parsed->{title},
                $parsed->{description},
                $parsed->{website_url},
                $parsed->{image_url},
                $parsed->{author},
                $parsed->{language},
                $parsed->{itunes_id},
                $feed_id,
            );

            for my $ep (@{ $parsed->{episodes} }) {
                my $existing = $db->query(
                    'SELECT id FROM podcast_episodes WHERE feed_id = ? AND guid = ?',
                    $feed_id, $ep->{guid},
                )->hash;

                if ($existing) {
                    $db->query(
                        q{UPDATE podcast_episodes
                              SET title = ?, description = ?, audio_url = ?,
                                  duration_sec = ?, published_at = ?,
                                  image_url = ?, episode_number = ?, season_number = ?,
                                  updated_at = now()
                            WHERE id = ?},
                        $ep->{title}, $ep->{description}, $ep->{audio_url},
                        $ep->{duration_sec}, $ep->{published_at}, $ep->{image_url},
                        $ep->{episode_number}, $ep->{season_number},
                        $existing->{id},
                    );
                    $updated++;
                }
                else {
                    $db->query(
                        q{INSERT INTO podcast_episodes
                              (feed_id, guid, title, description, audio_url,
                               duration_sec, published_at, image_url,
                               episode_number, season_number)
                          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)},
                        $feed_id, $ep->{guid}, $ep->{title}, $ep->{description},
                        $ep->{audio_url}, $ep->{duration_sec}, $ep->{published_at},
                        $ep->{image_url}, $ep->{episode_number}, $ep->{season_number},
                    );
                    $inserted++;
                }
            }

            $db->query('COMMIT');

            my $feed_row = $pg->db->query(
                'SELECT title, feed_url, image_url FROM podcast_feeds WHERE id = ?',
                $feed_id,
            )->hash;

        eval {
            $redis->db->publish('resonance:podcast' => encode_json({
                event    => 'refreshed',
                feed_id  => $feed_id + 0,
                title    => $feed_row ? $feed_row->{title} : undef,
                inserted => $inserted,
                updated  => $updated,
                total    => scalar @{ $parsed->{episodes} },
            }));
        };
        $app->log->warn("Podcast: publish failed: $@") if $@;

            1;
        } or do {
            my $err = $@;
            $db->query('ROLLBACK');
            $app->log->error("Podcast: DB error during refresh: $err");
            $job->fail("db error: $err");
            return;
        };

        $app->log->info("Podcast: feed $feed_id refreshed — $inserted inserted, $updated updated");

        $job->finish({
            ok        => 1,
            inserted  => $inserted,
            updated   => $updated,
            total     => scalar @{ $parsed->{episodes} },
        });
    });
}

1;
