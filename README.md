# Website-Content-Optimizer
Automatically optomize all content on my portfolio website, but could be applied to any website

## What does this script do?

This script was designed for any application that requires deployment on the web, in order to create the fastest websites possible.

It works by applying a different compression algorithm to many different file types; including:
- PNGs (using [pngquant](https://github.com/kornelski/pngquant))
- JPGs and JPEGs (using [jpegoptim](https://github.com/tjko/jpegoptim))
- MOVs and MP4s (using [ffmpeg](https://github.com/FFmpeg/FFmpeg) for compression + resizing)

as well as resizing images using [imagemagick](https://github.com/ImageMagick/ImageMagick).

It also converts all HEIC or HEIF images to an optimized JPG format so that they can be deployed easily on the web.
Finally, all images are stripped of their EXIF data relating to location or camera information, for increased privacy.

## Method of Operation

For every file of these supported types, the following files are created:

| File Name | Description |
| --- | --- |
| name-original.ext | Original file 'original.ext' moved here |
| name-thumb.ext | Original file 'original.ext' thumbnail image, usually 20x reduction in file size |
| name.ext | Optimized version of 'original.ext', usually 5-10x reduction in file size |

Note that for Mov and Mp4 files, the thumbnail is created in JPG format.

## Command Line Arguments

| Argument | Description | Required |
| --- | --- | --- |
| -f <dirname> | Folder containing content to optimize | Yes |
| -r | If passed, will 'reload' all optimized files by first deleting then re-optimizing | No (flag) |
| -d | If passed, will delete all optimized files and move originals back to their original location | No (flag) |
| -h | If passed, display a small help message | No (flag) |

So, a sample command would look like: `bash optimize.sh -f public/content/pages -r`

## Required Libraries

All of the following are required to run this program:
- [pngquant](https://github.com/kornelski/pngquant)
- [jpegoptim](https://github.com/tjko/jpegoptim)
- [imagemagick](https://github.com/ImageMagick/ImageMagick)
- [exiftool](https://github.com/exiftool/exiftool)
- [ffmpeg](https://github.com/FFmpeg/FFmpeg)
