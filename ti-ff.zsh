#!/usr/local/bin/zsh

if which tput > /dev/null; then
	if tput colors > /dev/null; then
		ANSI_NC='\033[0m'
		ANSI_RED='\033[0;31m'
		ANSI_GREEN='\033[0;32m'
		ANSI_YELLOW='\033[0;33m'
		ANSI_BOLD_RED='\033[1;31m'
		ANSI_BOLD_GREEN='\033[1;32m'
		ANSI_BOLD_YELLOW='\033[1;33m'
	fi
fi

#These two are used to track the compression ratio in regards to the size of the input TIFF versus the size of the compressed PNG.
initial_size=0
final_size=0

#Initially, all valid TIFF paths are listed in $images_to_process. After each has been processed, a log is generated for it, depending on whether or not an error was encountered. The logs are formatted for human readability and are printed at the end.
images_to_process=()
success_log=()
fail_log=()

#This is a count of all TIFF files found that have a *.tif or *.tiff extension and, according to the file utility, appear to be TIFFs.
expected_total=0

#This is an English gerund phrase relating to the current step that the program is on. Unless it’s 'starting' or 'stopping', the current value of $step is printed with write_stats.
step='starting'

#This is the start time of the main processing loop, in seconds since the epoch. This is empty until said loop starts.
start_time=''

#This is a binary flag for whether a signal has interrupted the processing of an image.
interrupt=''

#This is a binary flag for whether lolcat (by moe@busyloop.net) was found. Its presence indicates that it is installed.
has_lolcat=''

#This is a binary flag for whether the date command was found. Its presence indicates that it is installed.
has_date=''

if which lolcat > /dev/null; then
	has_lolcat='true'
else
	unset has_lolcat
fi

if which date > /dev/null; then
	has_date='true'
else
	unset has_date
fi

#clean_up removes all pending TIFFs from the queue ($images_to_process) and logs them in $fail_log as cencelled. It also sets $interrupt to indicate that the image being processed that it has been interrupted.
clean_up() {
	interrupt='true'
	for unprocessed_file in $images_to_process; do
		fail_log+=( "${ANSI_BOLD_RED}✗${ANSI_NC} ${unprocessed_file}\t↛\t${ANSI_BOLD_YELLOW}cancelled${ANSI_NC}" )
	done
	images_to_process=()
	write_stats 'interrupting'
}

#get_file_size accepts the argument of one file and uses wc to send the file size in bytes to stdout.
get_file_size() {
	wc -c < "$1"
}

#get_now writes to stdout the current number of seconds since the epoch. If an argument is provided, it is numerically subtracted from what would have been output.
get_now() {
	now=$(date +%s)
	if [[ -n "$1" ]]; then
		echo "$(( now - ${1} ))"
	else
		echo "$now"
	fi
	unset now
}

#write_compression_ratio calculates the current compression ratio based on $initial_size and $final_size and writes a human-readable string of it to stdout. This function does not check for errors; please check that at least one image has been successfully processed before calling it. The value given in the output string represents the proportional difference in file size.
write_compression_ratio() {
	echo -n "compression ratio: $(printf "${ANSI_BOLD_GREEN}%.1f" $(( 100.0 * ( 1 - ( 1.0 * final_size / initial_size ) ) )))%${ANSI_NC}"
}

#write_stats sends to stdout a carriage return followed by information about the status and progress of the script. It is not followed by a newline. This is formatted for human readability. If an argument is present, it becomes the new value of $step before the stats are generated.
write_stats() {
	if [[ -n "$1" ]]; then
		step="$1"
	fi
	image_stats="${ANSI_GREEN}$(printf "%${#expected_total}u" ${#success_log})${ANSI_NC} TIFF image"
	if (( ${#success_log} != 1 )); then
		image_stats="${image_stats}s"
	else
		image_stats="${image_stats} "
	fi
	image_stats="${image_stats} out of ${ANSI_YELLOW}$expected_total${ANSI_NC} file"
	if (( expected_total != 1 )); then
		image_stats="${image_stats}s"
	else
		image_stats="${image_stats} "
	fi
	image_stats="${image_stats} processed"
	if (( ${#fail_log} > 0 )); then
		image_stats="${image_stats} and ${ANSI_RED}$(printf "%${#expected_total}u" ${#fail_log})${ANSI_NC} error"
		if (( ${#fail_log} != 1 )); then
			image_stats="${image_stats}s"
		else
			image_stats="${image_stats} "
		fi
	fi
	if (( ${#success_log} > 0 )); then
		image_stats="${image_stats}; $(write_compression_ratio)"
		image_stats="${image_stats}; progress: $(printf "${ANSI_BOLD_YELLOW}%.1f" $(( 100.0 * ( ${#success_log} + ${#fail_log} ) / expected_total )))%${ANSI_NC}"
	fi
	if [[ -v has_date && -n "$start_time" ]]; then
		elapsed_total_seconds="$(get_now $start_time)"
		image_stats="${image_stats}; total duration: $(printf '%02.2u:%02.2u:%02.2u' $((elapsed_total_seconds / 3600)) $(((elapsed_total_seconds % 3600) / 60)) $((elapsed_total_seconds % 3600)) )"
		unset elapsed_total_seconds
	fi
	if [[ -n "$step" && "$step" != 'starting' && "$step" != 'stopping' ]]; then
		image_stats="${image_stats}; $(printf "%-16.16s" "${step}…")"
	fi
	echo -n "\r${image_stats}"
}

#print_dir writes to stdout 'directory:\t' followed by the argument given, which is expected to be the path of the directory that the script is searching. This is for human readability; the pathname will be coloured with lolcat if available (indicated by the presence of $has_lolcat).
print_dir() {
	if [[ -v has_lolcat ]]; then
		echo -n 'directory: '
		echo "$1" | lolcat
	else
		echo -n "directory: ${ANSI_GREEN}$1{ANSI_NC}"
	fi
}

if [[ "$1" == '-h' || "$1" == '--help' || "$1" == '-?' ]]; then
	shift
	echo \
"${ANSI_BOLD_YELLOW}recursive_tiff_to_png${ANSI_NC}
usage: ti-ff [ -h | --help | -? ] [<directory>]

This script finds all TIFF files in the current directory (or the provided directory) and converts them all to PNGs using LibTIFF’s tiff2png command. The resulting PNGs are then compressed with OptiPNG. The TIFFs for which this process is successful are deleted.
Please note that, by design, this script strips all TIFF and PNG metadata from the output files; however, file access and modification times are copied from the deleted TIFFs to the output PNGs.
This script runs only in Z shell (zsh) and directly relies on the following utilities:
\t• LibTIFF’s tiff2png
\t• OptiPNG
\t• file (with the --mime-type option)
\t• touch (with the -r option)
\t• printf
\t• wc

Starting with an argument of '-h', '--help', or '-?' causes this message to be printed to stdout with no further actions.

status codes:
\t🄀 success
\t⒈ optional directory argument not found
\t⒉ process interrupted by SIGINT or SIGTERM
\t⒊ failure in at least one file
"
return 0
fi

trap clean_up SIGINT SIGTERM

if [[ -d $1 ]]; then
	cd $1
	if (( $? == 0 )); then
		print_dir "$1"
	else
		echo "directory “${ANSI_RED}$1${ANSI_NC}” not found" >&2
		return 1
	fi
	shift
else
	print_dir "$PWD"
fi

setopt nullglob
#This loop finds and counts all of the TIFF files that need to be processed.
for tiff_file in **/*.tif **/*.tiff; do
	if [[ -z "$interrupt" && -f "$tiff_file" && $(file -bp --mime-type "$tiff_file") == 'image/tiff' ]]; then
		((expected_total++))
		images_to_process+=( "$tiff_file" )
		write_stats 'searching'
	fi
done

if [[ -z "$interrupt" ]]; then
	if [[ -v has_date ]]; then
		start_time=$(get_now)
		echo "\nstart time: $(date -j -r $start_time '+%Y-%m-%d %H:%M:%S %Z')"
	fi

	#This loop does the heavy lifting. It runs on each path in $images_to_process until it’s empty, popping each element from the start of the list.
	while (( ${#images_to_process} > 0 )); do
		tiff_file=${images_to_process[1]}
		images_to_process[1]=()
		if [[ -f "$tiff_file" ]]; then #This is an extra check to be sure that the file’s still there.
			fail="" #This parameter contains a brief explanation of what went wrong, if anything. If it’s empty, then everything’s going okay.
			png_file="${tiff_file%.*}.png"
			write_stats 'checking'
			if [[ -e "$png_file" ]]; then #This prevents the script from overwriting a preexisting PNG.
				fail="PNG file already exists."
			else
				write_stats 'converting'
				tiff2png_log=''
				tiff2png_status=0
				if [[ "${tiff_file}" == */* ]]; then #Because tiff2png will only write the output PNG to the current directory or the provided one, this switch provides the target directory explicitly.
					tiff2png_log="$(tiff2png -destdir "./$(dirname "$tiff_file")" -compression 0 -interlace "${tiff_file}" 2>&1)"
					tiff2png_status=$?
				else
					tiff2png_log="$(tiff2png -destdir "./" -compression 0 -interlace "${tiff_file}" 2>&1)"
					tiff2png_status=$?
				fi
				if [[ $tiff2png_status -eq 0 && "$tiff2png_log" != '*tiff2png error*' ]]; then #This checks that tiff2png went smoothly before deciding to call optipng.
					write_stats 'compressing'
					optipng_log="$(optipng -o4 -i1 -fix -snip -clobber -force -strip all -out "${png_file}" "${png_file}" 2>&1)"
					if (( $? != 0 )); then #This checks that optipng went smoothly.
						if [[ -n "$interrupt" ]]; then #This checks for the special case where optipng was interrupted and provides an alternative error description.
							fail="optipng ${ANSI_BOLD_YELLOW}interrupted${ANSI_NC}"
						else
							fail="optipng failed: ❝${optipng_log}\t❞"
						fi
					fi
				else
					if [[ -n "$interrupt" ]]; then #This checks for the special case where tiff2png was interrupted and provides an alternative error description.
						fail="tiff2png ${ANSI_BOLD_YELLOW}interrupted${ANSI_NC}"
					else
						fail="tiff2png failed: ❝${tiff2png_log}\t❞"
					fi
				fi
				write_stats 'logging'
				if [[ -n $fail ]]; then #This looks at the value of $fail to determine whether any step encountered an error and then adds an entry to either $success_log or $fail_log.
					write_stats 'logging error'
					fail_log+=( "${ANSI_BOLD_RED}✗${ANSI_NC} ${tiff_file}\t↛\t${png_file}\n\t${fail}" )
				else
					write_stats 'logging success'
					success_log+=( "${ANSI_BOLD_GREEN}✓${ANSI_NC} ${tiff_file}\t→\t${png_file}" )

					#This keeps track of the compression ratio.
					(( initial_size += $(get_file_size "$tiff_file") ))
					(( final_size += $(get_file_size "$png_file") ))

					write_stats 'cleaning up'
					touch -r "$tiff_file" "$png_file" #The file access and modification times are copied from the TIFF to the output PNG.
					rm -f "${tiff_file}" #The TIFF deleted iff no errors were encountered for that file.
				fi
			fi
		fi
	done
fi
write_stats 'stopping'
setopt no_nullglob
echo "\n" #This is used to add a new line after the status message. (See write_stats.)

#This prints a final message containing the logs ($success_log and $fail_log) and the compression ratio, iff any files were processed.
if (( ( ${#success_log} + ${#fail_log}) > 0 )); then
	all_records=( $success_log $fail_log )
	echo "${(F)all_records}\n\n\n$(write_stats)"
fi
if (( ${#fail_log} > 0 )); then
	if [[ -n "$interrupt" ]]; then
		return 2
	else
		return 3
	fi
fi
