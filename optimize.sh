# script that does 3 things:

# - convert .JPG to .jpg
# - optimize JPGs
# - optimize PNGs
# - optimize video

# what you need to run this:

# - pngquant
# - imagemagick
# - exiftool
# - ghostscript

# sample run command: bash optimize.sh -f public/content/pages -r

#!/bin/bash

# Default arguments: gen DB and do not delete
deletePreviousFiles="false"
optimizeFiles="false"
prepareDirFiles="false"

while getopts f:drph flag
do
    case "${flag}" in
        f) # Optimize, but don't delete (default)
            filepath=${OPTARG}
            deletePreviousFiles="false"
            optimizeFiles="true"
            prepareDirFiles="true"
            ;;
        d) # Delete, but don't optimize
            deletePreviousFiles="true"
            optimizeFiles="false"
            prepareDirFiles="true"
            ;;
        r) # Delete then optimize
            deletePreviousFiles="true"
            optimizeFiles="true"
            prepareDirFiles="true"
            ;;

        p) # Prepare only
            prepareDirFiles="true"
            optimizeFiles="false"
            deletePreviousFiles="false"
            ;;

        h)
            echo "Aaron's ContentPrep Script V1"
            echo "Use -f <filepath> to specify directory"
            echo "Use -d to delete all old generated files without regenerating image cache"
            echo "Use -r to delete all old files and then regenerate image cache"
            echo "Use -p to run all name processing and filename conversion without generating cache"
            echo "Use -h to display this help message"
            exit 0
            ;;
    esac
done

echo "Running with params ->
        DeletePrevious: ${deletePreviousFiles}
        Optimize: ${optimizeFiles}
        PrepareFiles: ${prepareDirFiles}"

if [[ -z "$filepath" ]]; then
    echo "No directory specified; exiting" && exit 1
fi

if ! [ -d "$filepath" ]; then
    echo "Directory specified does not exist; exiting" && exit 1
fi

# Check whether required packages to run are installed
if ! [ -x "$(command -v gs)" ]; then
  echo 'Error: ghostscript is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v ffmpeg)" ]; then
  echo 'Error: ffmpeg is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v pngquant)" ]; then
  echo 'Error: pngquant is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v jpegoptim)" ]; then
  echo 'Error: jpegoptim is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v exiftool)" ]; then
  echo 'Error: exiftool is not installed.' >&2
  exit 1
fi

if ! [ -x "$(command -v convert)" ]; then
  echo 'Error: ImageMagick is not installed.' >&2
  exit 1
fi

change_exts=("JPG" "PNG" "MOV" "MP4" "HEIC" "HEIF" "PDF" "M4V")
optimize_exts=("jpg" "png" "mov" "mp4" "jpeg" "pdf")

containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# thanks https://gist.github.com/ahmed-musallam/27de7d7c5ac68ecbd1ed65b6b48416f9
pdfcompress()
{
   gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile=$2 $1; 
}

# Various counters for operations
fileCount=0
renameCount=0
compressCount=0
cleanupCount=0

# Runs all file name changing and renaming algorithms without optimization
prepare_dir () {
    shopt -s nullglob dotglob

    for pathname in "$1"/*; do
        if [ -d "$pathname" ]; then
            prepare_dir "$pathname"
        else
            fileCount=$((fileCount+1))
            filename=$(basename "$pathname")
            extension="${filename##*.}"
            filename="${filename%.*}"
            basepath=$(dirname "$pathname")

             # Check for uppercase pathname, and if found rename file
            containsElement "$extension" "${change_exts[@]}"
            if [[ $? -eq "0" ]]; then
                newpath="$basepath/$filename.$(echo $extension | tr '[:upper:]' '[:lower:]')"
                mv "$pathname" "$newpath"
                echo "Renaming filename $pathname"

                # reset pathname and extensions
                pathname=${newpath}
                filename=$(basename "$pathname")
                extension="${filename##*.}"
                filename="${filename%.*}"
                basepath=$(dirname "$pathname")

                renameCount=$((renameCount+1))
            fi

            # Check for heic, and if so convert to jpg
            containsElement "$extension" "heic"
            if [[ $? -eq "0" ]]; then
                newpath="$basepath/$filename.jpg"
                echo "Converting HEIC to jpg $pathname"
                convert ${pathname} -quality 90% ${newpath} > /dev/null 2>&1
                rm "${pathname}" # remove heic original

                # reset pathname and extensions
                pathname=${newpath}
                filename=$(basename "$pathname")
                extension="${filename##*.}"
                filename="${filename%.*}"
                basepath=$(dirname "$pathname")

                renameCount=$((renameCount+1))
            fi

            # Check for m4v, and if so convert to mp4
            containsElement "$extension" "m4v"
            if [[ $? -eq "0" ]]; then
                newpath="$basepath/$filename.mp4"
                echo "Converting m4v to mp4 $pathname"
                ffmpeg -hide_banner -loglevel error -y -i ${pathname} -c copy ${newpath} # reencode in mp4
                rm "${pathname}" # remove m4v original

                # reset pathname and extensions
                pathname=${newpath}
                filename=$(basename "$pathname")
                extension="${filename##*.}"
                filename="${filename%.*}"
                basepath=$(dirname "$pathname")

                renameCount=$((renameCount+1))
            fi
        fi
    done
}

# Perform actual optimization
optimize_dir () {
    shopt -s nullglob dotglob

    for pathname in "$1"/*; do
        if [ -d "$pathname" ]; then
            optimize_dir "$pathname"
        else
            fileCount=$((fileCount+1))
            filename=$(basename "$pathname")
            extension="${filename##*.}"
            filename="${filename%.*}"
            basepath=$(dirname "$pathname")

            # then, check for full size copy for supported file extensions
            containsElement "$extension" "${optimize_exts[@]}"
            if [[ $? -eq "0" ]]; then
                if [[ ${pathname} != *"_original"* ]] 2> /dev/null 2>&1 && [[ ${pathname} != *"_thumb"* ]] ; then
                    original_path="$basepath/`echo $filename`_original.$extension"
                    thumb_path_image="$basepath/`echo $filename`_thumb.$extension" # images follow original extension
                    thumb_path_video="$basepath/`echo $filename`_thumb.jpg" #videos are always jpg
                    if [[ ! -f $original_path ]]; then
                        echo "Optimizing $pathname; no original version found"

                        # Copy original file to new "original" prefixed filename
                        cp "$pathname" "$original_path"

                        case $extension in

                            png)
                                # Generate large optimized version of photo
                                convert "${original_path}" -resize 1920x1080\> "${pathname}" > /dev/null 2>&1
                                pngquant --speed 1 --force --quality=60-100 --strip --skip-if-larger --verbose --output "${pathname}" "${pathname}" > /dev/null 2>&1

                                # Generate thumbnail image
                                convert "${pathname}" -resize 320x180\> "${thumb_path_image}" > /dev/null 2>&1
                                pngquant --speed 1 --force --quality=20-100 --strip --skip-if-larger --verbose --output "${thumb_path_image}" "${thumb_path_image}" > /dev/null 2>&1
                                ;;
                            
                            jpg|jpeg)
                                # Generate large optimized version of photo
                                convert "$original_path" -resize 1920x1080\> "${pathname}" > /dev/null 2>&1
                                jpegoptim --all-progressive --max=80 "${pathname}" > /dev/null 2>&1

                                # Generate thumbnail image
                                convert "${pathname}" -resize 320x180\> "${thumb_path_image}" > /dev/null 2>&1
                                jpegoptim --all-progressive --max=20 "${pathname}" > /dev/null 2>&1
                                ;;

                            # For video formats, scale the video down by half and generate thumbnail
                            mov)
                                ffmpeg -hide_banner -loglevel error -y -i "${original_path}" -c:v libx264 -c:a aac -vf "[in]format=yuv420p[middle];[middle]scale=trunc(iw/4)*2:trunc(ih/4)*2[out]" -movflags faststart -crf 25 "${pathname}"
                                ffmpeg -hide_banner -loglevel error -y -i "${pathname}" -frames:v 1 -vf scale=320:-2 -q:v 3 "${thumb_path_video}"
                                ;;

                            mp4)
                                ffmpeg -hide_banner -loglevel error -y -i "${original_path}" -vf "scale=trunc(iw/4)*2:trunc(ih/4)*2" -c:v libx264 -movflags faststart -crf 20 "${pathname}"
                                ffmpeg -hide_banner -loglevel error -y -i "${pathname}" -frames:v 1 -vf scale=320:-2 -q:v 3 "${thumb_path_video}"
                                ;;

                            pdf)
                                pdfcompress "${original_path}" "${pathname}" > /dev/null 2>&1
                                ;;

                            *)
                                echo "Unknown file type"
                                ;;
                        esac
                        
                        # remove EXIF data
                        exiftool -overwrite_original -all= -TagsFromFile @ -Orientation -ColorSpaceTags ${pathname} > /dev/null 2>&1

                        compressCount=$((compressCount+1))
                    fi
                fi
            fi

        fi
    done
}

cleanup_dir () {
    shopt -s nullglob dotglob

    for pathname in "$1"/*; do
        if [ -d "$pathname" ]; then
            cleanup_dir "$pathname"
        else
            fileCount=$((fileCount+1))
            filename=$(basename "$pathname")
            extension="${filename##*.}"
            filename="${filename%.*}"
            basepath=$(dirname "$pathname")

            # Delete any thumbnail image
            if [[ "$filename" == *"_thumb"* ]]; then
                rm "${pathname}" # remove heic original
                cleanupCount=$((cleanupCount+1))
            fi

            # Move any original back onto its target
            if [[ "$filename" == *"_original"* ]]; then
                original_filename=`echo ${filename} | sed 's|\(.*\)_.*|\1|' `
                original_path="$basepath/`echo $original_filename`.$extension"

                # Move original file back to its proper path
                mv "${pathname}" "${original_path}"

                cleanupCount=$((cleanupCount+1))
            fi

        fi
    done
}


# Run main logic

if [[ ${deletePreviousFiles} == "true" ]]; then
    echo "Starting cleanup"
    cleanup_dir "$filepath"
    echo "Cleanup finished; removed ${cleanupCount} files"
fi

if [[ ${prepareDirFiles} == "true" ]]; then
    echo "Starting FS preparation pass"
    prepare_dir "$filepath"
    echo "Preparation finished; renamed/fixed extensions on ${renameCount} files"
fi

if [[ ${optimizeFiles} == "true" ]]; then
    echo "Starting optimization"
    optimize_dir "$filepath"
    echo "Optimization complete"
    echo "Checked $fileCount files; optimized and compressed $compressCount"
fi
echo "Script finished"
