#!/bin/bash
#
# primitive front-end bash script
#

PRIMITIVE_PIC_BIN=${PRIMITIVE_PIC_BIN:=~/gocode/bin/primitive}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.
NUM_DEF=500
PRIM_DEF=1 # triangles
CONVERT_OPTS=${CONVERT_OPTS:="-delay 20 -loop 0"}
PRIMITIVE_PIC_DEBUG=${PRIMITIVE_PIC_DEBUG:=""}

info() {
	echo -e $*
}

debug() {
	[ -n "$PRIMITIVE_PIC_DEBUG" ] && info "Debug: $*"
}

warn() {
	info "Warning: $*"
}

error() {
	info "Error: $*"
}

die() {
	error $*
	exit 1
}

run() {
	info $*
	$*
	[ $? -ne 0 ] && exit $?
}

# Initialize our own variables:
output=""
verbose=""
input=""
num=${PRIMITIVE_PIC_NUM:=$NUM_DEF}
primitive=${PRIMITIVE_PIC_PRIM:=$PRIM_DEF}
wdir=${PRIMITIVE_PIC_WDIR:=""}
viewer=${PRIMITIVE_PIC_VIEWER:=""}
exif=""
loop_num0=""
loop_num1=""
loop_inc=""
gifify=""
resize=""

show_help() {
cat <<- HELP
   Usage is: $(basename $0) [opts] -i input [-o output]

   Automatically generates output with -m and -n if not given

      -i  input
      -o  output file (optional)
      -d  output directory (default is same as input directory)
      -n  num primitives (default is $NUM_DEF)
      -m  primitive type, see main program options (default is $PRIM_DEF, triangle)
      -l  num0,inc,num1  - loop from -n num0 to -n num1 with an increment of inc
      -g  output.gif - gif animate looped images created with -l
      -z  WidthxHeight (eg resize with mogrify - 640x480)
      -x  copy exif with exiftool
      -h  this help
      -V  viewer
      -v  verbose
      -vv very verbose

   Environment Variables

      PRIMITIVE_PIC_BIN    - path to golang binary
      PRIMITIVE_PIC_NUM    - default value for -n parameter
      PRIMITIVE_PIC_PRIM   - default value for -m parameter
      PRIMITIVE_PIC_WDIR   - default value for -d parameter
      PRIMITIVE_PIC_VIEWER - default value for image viewer application
      PRIMITIVE_PIC_DEBUG  - set to anything to enable debug
      CONVERT_OPTS         - convert gifify opts (default $CONVERT_OPTS)

   Primitive types are shown in main program help below,

HELP
	echo -e $($PRIMITIVE_PIC_BIN -h)
}

let skip=0
while getopts ":hvxi:o:d:n:m:l:g:z:V:" opt; do
    case "$opt" in
    h)
		show_help
		exit 0
		;;
    v)
		if [ -z "$verbose" ]; then
			verbose="-v"
		else
			verbose="-vv"
		fi
        ;;
	d)
		wdir=$OPTARG
		debug "Setting wdir=$wdir"
		;;
	i)
		input=$OPTARG
		debug "Setting input=$input"
		;;
    o)
		output=$OPTARG
		debug "Setting output=$output"
        ;;
	n)
		num=$OPTARG
		debug "Setting num=$num"
		;;
	m)
		primitive=$OPTARG
		debug "Setting primitive=$primitive"
		;;
	l)
		let loop_num0=$(echo $OPTARG | cut -f1 -d',')
		let loop_inc=$(echo $OPTARG | cut -f2 -d',')
		let loop_num1=$(echo $OPTARG | cut -f3 -d',')
		debug "Setting loop_num0,loop_inc,loop_num1=$loop_num0,$loop_inc,$loop_num1"
		;;
	g)
		gifify=$OPTARG
		debug "Setting gifify=$gifify"
		;;
	z)
		resize=$OPTARG
		debug "Setting resize=$resize"
		;;
	V)
		viewer=$OPTARG
		debug "Setting viewer=$viewer"
		;;
	x)
		exif=exiftool
		debug "Setting exif=$exif"
		;;
	*)
		skip=$((skip+1))
		;;
    esac
done

debug "OPTIND=$OPTIND, skip=$skip"
skip=$((OPTIND-skip-1))
shift $skip

# pass on leftover args
leftovers=""
[ $# -gt 0 ] && leftovers=$* && echo leftovers=$leftovers

[ -z "$input" ] && die "Input file not given"
[ -z "$num" ] && info "Defaulting -n $NUM_DEF" && num=$NUM_DEF
[ -z "$primitive" ] && info "Defaulting -m $PRIM_DEF" && primitive=$PRIM_DEF

RE_FILE_URI='^file:\/\/\/(.*)'
if [[ $input =~ $RE_FILE_URI ]]; then
	info "Stripping file uri: $input"
	input="/${BASH_REMATCH[1]}"
fi

dn=$(dirname "$input")
[ -z "$wdir" ] && wdir=$dn && debug "Setting wdir=$wdir"
mkdir -p "$wdir"

#0=combo 1=triangle 2=rect 3=ellipse 4=circle 5=rotatedrect 6=beziers 7=rotatedellipse 8=polygon (default 1)
PRIMITIVES=(combo triangle rect ellipse circle rotatedrect beziers rotatdellipse polygon)
[ $primitive -ge ${#PRIMITIVES[*]} ] && die "Unknown primitive value $primitive"
primitive_name=${PRIMITIVES[$primitive]}

#echo primitive=$primitive
#echo primitive_name=$primitive_name

make_output() {
	n0=$(printf "%08d" $1)
	bn=$(basename "$input")
	ext="${bn##*.}"
	fn="${bn%.*}"
	on="${fn}_${primitive_name}_${n0}.${ext}"
	output="$wdir/$on"
}

if [ -n "$loop_num0" -a -n "$loop_num1" -a -n "$loop_inc" ]; then
	mog=$(type -p mogrify)
	[ $? -ne 0 ] && warn "ImageMagick mogrify not found"
	cvt=$(type -p convert)
	[ $? -ne 0 ] &&	warn "ImageMagick convert not found"

	info "Loop with num=$loop_num0 to $loop_num1 with increment of $loop_inc"
	files_asc=""
	files_desc=""
	for num in $(seq $loop_num0 $loop_inc $loop_num1); do
		make_output $num
		if [ -f "$output" ]; then
			warn "Skipping existing file: $output"
		else
			debug "Processing $output"
			run ~/gocode/bin/primitive $verbose -i "$input" -o "$output" -n $num -m $primitive $leftovers
		fi
		files_asc="$files_asc $output"
		files_desc="$output $files_desc"
		if [ ! -z "$resize" -a ! -z "$mog" ]; then
			run $mog -resize $resize $output
		fi
	done
	if [ -n "$gifify" -a -n "$cvt" ]; then
		cd $wdir
		run $cvt $CONVERT_OPTS $files_asc $files_desc $gifify
		cd -
	fi
else
	# create output from input if not given
	[ -z "$output" ] && make_output $num

	#~/gocode/bin/primitive -i /data/photos/steeve/nexus_5/DCIM/Camera/IMG_20170610_122050.jpg -o scenery_1000.jpg -m 1 -n 1000
	cmd="~/gocode/bin/primitive $verbose -i \"$input\" -o \"$output\" -n $num -m $primitive $leftovers"
	run ~/gocode/bin/primitive $verbose -i "$input" -o "$output" -n $num -m $primitive $leftovers

	[ ! -z "$exif" ]   && run exiftool -TagsFromFile "$input" "$output"
	[ ! -z "$viewer" ] && run $viewer "$output"
fi
