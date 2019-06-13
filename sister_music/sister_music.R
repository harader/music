# Look at sister music!!!!!
# May 2019

################################################################################
## Setup
################################################################################

library(tidyverse)
library(stringr)
library(ggplot)
library(hayley.plot)
library(spotifyr)
library(purrr)

# Previously stored
lindsay_id <- Sys.getenv("LINDSAY_SPOTIFY_ID")
hayley_id <- Sys.getenv("HAYLEY_SPOTIFY_ID")

get_playlist_info <- function(myid) {

  playlists <- get_user_playlists(myid, limit = 50) %>%
    filter(tracks.total > 1)

  all <- map_df(playlists$id, function(x) {

    message(playlists$name[playlists$id == x])

    playlist_tracks <- get_playlist_tracks(x, limit = 100) %>%
      # filter out songs we don't have data on
      filter(!is.na(track.id)) %>%
      # pull out the first artist that's included
      mutate(artist = map_chr(track.artists, function(x) x$name[1])) %>%
      select(id = track.id, artist)

    if (nrow(playlist_tracks) > 0) {
      playlist_tracks <- playlist_tracks$id %>%
        get_track_audio_features() %>%
        mutate(playlist_id = x) %>%
        full_join(playlist_tracks)

    }

    playlist_tracks

    }) %>%
      full_join(select(playlists, name, playlist_id = id))
}

hha <- get_playlist_info(hayley_id)
lla <- get_playlist_info(lindsay_id)
ef <- get_playlist_info("emmy72598")

valence_plot <- function(df, title) {

  df %>%
    group_by(name) %>%
    summarize(
      valence_mean = mean(valence, na.rm = T),
      valence_sd = sd(valence, na.rm = T)
    ) %>%
    arrange(valence_mean) %>%
    mutate(name = factor(name, levels = unique(.$name))) %>%
    filter(!is.na(valence_mean)) %>%
    ggplot(aes(x = name, xend = name)) +
    geom_segment(
      aes(yend = valence_mean - valence_sd,
          y = valence_mean + valence_sd, color = valence_mean),
      size = 3, alpha = .25) +
    geom_point(aes(y = valence_mean, fill = valence_mean),
               pch = 21, size = 3) +
    theme(panel.grid.major.y = element_blank(),
          panel.grid.minor.x = element_blank(),
          axis.text.y = element_text(size = 8)) +
    coord_flip() +
    scale_color_gradient2(
      low = hayley_colors[1], high = "pink",
      mid = combo_color("white", combo_color(hayley_colors[1], "pink")),
      midpoint = .4) +
    scale_fill_gradient2(
      low = hayley_colors[1], high = "pink",
      mid = combo_color("white", combo_color(hayley_colors[1], "pink")),
      midpoint = .4) +
    labs(x = "Playlist", y = "Happiness Metric",
       title = str_glue("{title} Playlists Ranked,\nFrom Least to Most Happy")) +
  annotate("label", label = "Happier\nSongs",
           label.size = 0, lineheight = .8,  x = 4, y = .65, family = "Lato") +
  annotate("segment",
           x = 2, y = .6, yend = .7, arrow = arrow(length = grid::unit(.25, "cm")),
           xend = 2, color = combo_color("pink", "grey50"),
           size = 1) +
  guides(color = F, fill = F)
}

# Let's look at the valence of our playlists
valence_plot(hha, "Hayley's")
valence_plot(lla, "Lindsay's")
valence_plot(ef, "Emily's")

p <- mutate(hha, person = "Hayley") %>%
  bind_rows(mutate(lla, person = "Lindsay")) %>%
  bind_rows(mutate(ef, person = "Emily")) %>%
  ggplot(aes(fill = person, x = valence,
             y = energy,
             color = person))+
  stat_density_2d(aes(alpha = ..level..),
                  geom = "polygon",
                  size = .1) +
  lapply(list(scale_fill_manual, scale_color_manual), function(f) {
    f(values = c(hayley_colors[1], hayley_colors[3], hayley_colors[7]))
  }) +
  labs(x = "Happiness", y = "Energy") +
  guides(alpha = F) +
  scale_alpha_continuous(range = c(.2, 0.75))

p + facet_wrap(~person)


agg2 <- function(df, title = "no one") {
  df %>%
    group_by(name) %>%
    summarize(
      valence_mean = mean(valence, na.rm = T),
      valence_sd = sd(valence, na.rm = T),
      energy_mean = mean(energy, na.rm = T),
      energy_sd = sd(energy, na.rm = T),
      n = n()
    ) %>%
    mutate(person = title)
}


scatter <- function(df) {
agg2(df) %>%
  ggplot(aes(x = valence_mean, y = energy_mean)) +
  geom_point(
    aes(color = valence_mean * energy_mean), size = 12, alpha = .25
  ) +
  geom_text(aes(label = str_wrap(name, 10)),
            lineheight = .8, size = 3) +
  theme(panel.grid.minor = element_blank()) +
    labs(x = "Happiness Metric",
         y = "Energy Metric") +
    annotate("label",
             x = .4, y = .175,
             label = "Happier\nPlaylists",
             label.size = 0, family = "Lato",
             lineheight = .8, fontface = "bold") +
    annotate("label", x = .65, y = .3,
             label = "Higher\nEnergy\nPlaylists",
             label.size = 0, lineheight = .8,
             family = "Lato", fontface = "bold") +
    annotate("segment",
             x = c(.425, .65),
                   xend = c(.475, .65),
                   y = c(.175, .335),
                   yend = c(.175, .405),
             arrow = arrow(length = grid::unit(.25, 'cm'))) +
    guides(fill = F, color = F) +
    lapply(list(scale_x_continuous, scale_y_continuous), function(f) {
      f(limits = c(0.1, 0.85))
    })
}

scatter(hha) + labs(title = "Hayley")
scatter(lla) + labs(title = "Lindsay")
scatter(ef) + labs(title = "Emily")

test <- hha %>%
  select(danceability, energy, key, loudness, mode, speechiness, acousticness, instrumentalness,
         liveness, valence, tempo)
kmeans(test, 5)
