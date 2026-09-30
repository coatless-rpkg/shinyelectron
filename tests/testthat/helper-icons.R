# Icon files that hold only the header, which is all that icon_size() reads.
# Each lives until `env` exits.

# A 4-byte big-endian unsigned integer
icon_uint32 <- function(x) {
  as.raw(x %/% 256^(3:0) %% 256)
}

# A PNG of `width` x `height` pixels
local_png_icon <- function(width, height = width, fileext = ".png",
                           env = parent.frame()) {
  path <- withr::local_tempfile(fileext = fileext, .local_envir = env)
  signature <- as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a))
  writeBin(c(signature, icon_uint32(13), charToRaw("IHDR"),
             icon_uint32(width), icon_uint32(height),
             as.raw(c(8, 6, 0, 0, 0)), raw(4)), path)
  path
}

# An .icns file with an entry of each type in `types`, such as "ic10". The
# image data starts as a PNG does, or, with `png = FALSE`, as a JPEG 2000
# image does, which older .icns files hold.
local_icns_icon <- function(types, png = TRUE, env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".icns", .local_envir = env)
  data <- if (png) {
    as.raw(c(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a))
  } else {
    as.raw(c(0x00, 0x00, 0x00, 0x0c, 0x6a, 0x50, 0x20, 0x20))
  }
  entries <- unlist(lapply(types, function(type) {
    c(charToRaw(type), icon_uint32(8 + length(data)), data)
  }))
  writeBin(c(charToRaw("icns"), icon_uint32(8 + length(entries)), entries),
           path)
  path
}

# An .ico file with a square image of each size in `sizes`
local_ico_icon <- function(sizes, env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".ico", .local_envir = env)
  # Each entry starts with the width and the height, where 0 stands for 256.
  entries <- unlist(lapply(sizes, function(size) {
    c(as.raw(size %% 256), as.raw(size %% 256), raw(14))
  }))
  writeBin(c(as.raw(c(0, 0, 1, 0, length(sizes), 0)), entries), path)
  path
}
