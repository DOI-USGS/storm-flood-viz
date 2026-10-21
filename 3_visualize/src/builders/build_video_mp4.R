#' Encode animation frames to MP4.
#'
#' Assembles title, flood, crossfade, and end frames into a single MP4 using
#' av_encode_video. Crossfade frames are morphed with magick and written
#' to a temp directory since av takes file paths, not in-memory images.
#'
#' Right after the title hold, the last frame of the data-viz sequence is
#' held a bit longer as a teaser
#'
#' @param title_frame_path Character. Path to the title/opening PNG.
#' @param flood_frame_paths Character vector. Ordered paths to flood stage PNGs.
#' @param end_frame_path Character. Path to the end/closing PNG.
#' @param output_path Character. Output .mp4 file path.
#' @param fps Numeric. Frames per second (default 2).
#' @param title_hold Integer. Number of times to repeat the title frame (default 8).
#' @param fade_frames Integer. Number of crossfade frames between last flood and end (default 10).
#' @param end_hold Integer. Number of times to repeat the end frame (default 4).
#' @param teaser_hold Integer. Number of times to repeat the teaser (last
#'   data-viz frame) shown right after the title (default 3).
#' @return Character. The output file path.
encode_flood_mp4 <- function(title_frame_path, flood_frame_paths, end_frame_path,
                             output_path, fps = 2, title_hold = 8L,
                             fade_frames = 10L, end_hold = 4L, teaser_hold = 3L) {
  # targets returns branched file paths in hash order, not pattern order.
  # Frame filenames are timestamp-based so string sort gives chronological order.
  flood_frame_paths <- sort(flood_frame_paths)
  last_flood_path <- flood_frame_paths[length(flood_frame_paths)]

  last_flood_img <- image_read(last_flood_path)
  end_img   <- image_read(end_frame_path)
  crossfade <- image_morph(
    c(last_flood_img, end_img),
    frames = fade_frames
  )

  tmp_dir <- tempfile("crossfade_")
  dir.create(tmp_dir)
  crossfade_paths <- file.path(
    tmp_dir, sprintf("crossfade_%04d.png", seq_len(fade_frames))
  )
  for (i in seq_len(fade_frames)) {
    image_write(crossfade[i], crossfade_paths[i])
  }

  # Encode at 24 fps for socials
  encode_fps <- 24L
  reps <- encode_fps / fps

  all_frame_paths <- c(
    rep(title_frame_path, title_hold * reps),
    rep(last_flood_path, teaser_hold * reps),
    rep(flood_frame_paths, each = reps),
    rep(crossfade_paths, each = reps),
    rep(end_frame_path, end_hold * reps)
  )

  av_encode_video(
    input = all_frame_paths,
    output = output_path,
    framerate = encode_fps,
    vfilter = "scale=trunc(iw/2)*2:trunc(ih/2)*2"
  )

  output_path
}

#' Encode animation frames to MP4 with no title/end bookend frames — just
#' the frames back to back, each repeated to hit encode_fps.
#'
#' The last frame is held a bit longer as a teaser before the sequence plays
#' from the start, so playback order is last (held), first, second, ..., last.
#'
#' @param frame_paths Character vector. Ordered paths to animation frame PNGs.
#' @param output_path Character. Output .mp4 file path.
#' @param fps Numeric. Display frames per second (default 2).
#' @param teaser_hold Integer. Number of times to repeat the teaser (last
#'   frame) shown before the sequence starts (default 3).
#' @return Character. The output file path.
encode_barplot_mp4 <- function(frame_paths, output_path, fps = 2, teaser_hold = 3L) {
  frame_paths <- sort(frame_paths)
  last_frame_path <- frame_paths[length(frame_paths)]

  encode_fps <- 24L
  reps <- encode_fps / fps

  all_frame_paths <- c(
    rep(last_frame_path, teaser_hold * reps),
    rep(frame_paths, each = reps)
  )

  av_encode_video(
    input = all_frame_paths,
    output = output_path,
    framerate = encode_fps,
    vfilter = "scale=trunc(iw/2)*2:trunc(ih/2)*2"
  )

  output_path
}
