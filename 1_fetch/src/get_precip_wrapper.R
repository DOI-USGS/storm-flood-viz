source_python("1_fetch/src/get_precip.py")

download_precip_r <- function(..., py_script) {
  reticulate::source_python(py_script)
  download_precip(...)
}
