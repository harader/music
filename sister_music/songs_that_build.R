playlists <- map_df(c("LINDSAY_SPOTIFY_ID", "HAYLEY_SPOTIFY_ID"), function(x) {
  get_user_playlists(Sys.getenv(x), limit = 20)
}) %>%
  filter(tracks.total > 1)

get_sections <- function(id, name) {
  df <- get_track_audio_analysis(id)
  df$sections %>%
    mutate(name = name, id = id)
}

get_playlist_info <- function(x) {

  message(playlists$name[playlists$id == x])

  playlist_tracks <- get_playlist_tracks(x, limit = 100) %>%
    # filter out songs we don't have data on
    filter(!is.na(track.id)) %>%
    # pull out the first artist that's included
    mutate(artist = map_chr(track.artists, function(x) x$name[1])) %>%
    select(id = track.id, artist, track.name)

  map2_df(.x = playlist_tracks$id, .y = playlist_tracks$track.name, .f = get_sections)

}

df <- map_df(playlists$id, get_playlist_info) %>%
  unique()

final <- map_df(unique(df$id), function(x) {

  message(unique(df$name[df$id == x]))

  sub <- df[df$id == x, ] %>%
    # calculate z score
    mutate(
      loudness_z = (loudness - mean(loudness)) / sd(loudness),
      tempo_z = (tempo - mean(tempo)) / sd(tempo)
    ) %>%
    arrange(start) %>%
    mutate(dy = 0, change = 0, metric = tempo_z * loudness_z, group = 0)

  # calculate derivative
  for (i in 2:nrow(sub)) {
    sub$dy[i] <-
      (sub$metric[i] - sub$metric[i - 1]) / (sub$start[i] - sub$start[i - 1])
  }

  sub$direction <- sign(sub$dy)

  # note when the derivative changes
  n <- 0
  for (i in 2:nrow(sub)) {

    sub$change[i] <- as.numeric(sub$direction[i] != sub$direction[i - 1])

    # group them by sections
    if (sub$change[i] == 1) n <- n + 1

    sub$group[i] <- n

  }
  sub
})

# group the top songs
top <- final %>%
  #  filter(direction == 1) %>%
  group_by(id, name, group) %>%
  summarize(min = min(metric), max = max(metric)) %>%
  mutate(dif = max - min) %>%
  arrange(desc(dif)) %>%
  select(name, dif) %>%
  ungroup() %>%
  filter(row_number() <= 35) %>%
  pull(id) %>%
  unique()

pl <- spotifyr::create_playlist(Sys.getenv("HAYLEY_SPOTIFY_ID"), name = "Build 4")
spotifyr::add_tracks_to_playlist(pl$id,
                                 paste0("spotify:track:", top))

