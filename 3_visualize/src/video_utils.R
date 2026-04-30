#' Encode animation frames to MP4.
#'
#' Assembles title, flood, crossfade, and end frames into a single MP4 using
#' av::av_encode_video. Crossfade frames are morphed with magick and written
#' to a temp directory since av takes file paths, not in-memory images.
#'
#' @param title_frame_path Character. Path to the title/opening PNG.
#' @param flood_frame_paths Character vector. Ordered paths to flood stage PNGs.
#' @param end_frame_path Character. Path to the end/closing PNG.
#' @param output_path Character. Output .mp4 file path.
#' @param fps Numeric. Frames per second (default 2).
#' @param title_hold Integer. Number of times to repeat the title frame (default 8).
#' @param fade_frames Integer. Number of crossfade frames between last flood and end (default 10).
#' @param end_hold Integer. Number of times to repeat the end frame (default 4).
#' @return Character. The output file path.
encode_flood_mp4 <- function(title_frame_path, flood_frame_paths, end_frame_path,
                             output_path, fps = 2, title_hold = 8L,
                             fade_frames = 10L, end_hold = 4L) {
  flood_imgs <- magick::image_read(flood_frame_paths)
  flood_imgs <- magick::image_coalesce(flood_imgs)
  end_img <- magick::image_read(end_frame_path)
  crossfade <- magick::image_morph(
    c(flood_imgs[length(flood_imgs)], end_img),
    frames = fade_frames
  )

  tmp_dir <- tempfile("crossfade_")
  dir.create(tmp_dir)
  crossfade_paths <- file.path(tmp_dir, sprintf("crossfade_%04d.png", seq_len(fade_frames)))
  for (i in seq_len(fade_frames)) {
    magick::image_write(crossfade[i], crossfade_paths[i])
  }

  all_frame_paths <- c(
    rep(title_frame_path, title_hold),
    flood_frame_paths,
    crossfade_paths,
    rep(end_frame_path, end_hold)
  )

  av::av_encode_video(
    input = all_frame_paths,
    output = output_path,
    framerate = fps,
    vfilter = "scale=trunc(iw/2)*2:trunc(ih/2)*2"
  )

  output_path
}
