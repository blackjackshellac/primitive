#!/bin/bash
#
# primitive front-end bash script
#

PRIMITIVE=~/gocode/bin/primitive

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.
NUM_DEF=500
PRIM_DEF=1 # triangles

# Initialize our own variables:
output=""
verbose=""
input=""
num=${PRIMITIVE_PIC_NUM:=NUM_DEF}
primitive=${PRIMITIVE_PIC_PRIM:=PRIM_DEF}
wdir=${PRIMITIVE_PIC_WDIR:=""}
viewer=${PRIMITIVE_PIC_VIEWER:=""}
exif=""

info() {
	echo -e $*
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

show_help() {
cat <<- HELP
	Usage is: $0 [opts] -i input [-o output]

	Automatically generates output with -m and -n if not given

	-i input
	-o output file (optional)
	-d output directory (default is same as input directory)
	-n (default is $NUM_DEF)
	-m (default is $PRIM_DEF, triangle)
	-x  copy exif with exiftool)
	-h  this help
	-v  verbose
	-vv very verbose

Environment Variables

PRIMITIVE_PIC_NUM    - default value for -n parameter
PRIMITIVE_PIC_PRIM   - default value for -m parameter
PRIMITIVE_PIC_WDIR   - default value for -d parameter
PRIMITIVE_PIC_VIEWER - default value for image viewer application

HELP
	echo -e $($PRIMITIVE -h)
}

let skip=0
while getopts ":hvxi:o:d:n:m:" opt; do
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
		;;
	i)
		input=$OPTARG
		;;
    o)
		output=$OPTARG
        ;;
	n)
		num=$OPTARG
		;;
	m)
		primitive=$OPTARG
		;;
	x)
		exif=exiftool
		;;
	*)
		skip=$((skip+1))
		;;
    esac
done

#echo OPTIND=$OPTIND, skip=$skip
skip=$((OPTIND-skip-1))
shift $skip

# pass on leftover args
leftovers=""
[ $# -gt 0 ] && leftovers=$* && echo leftovers=$leftovers

[ -z "$input" ] && die "Input file not given"
[ -z "$num" ] && info "Defaulting -n $NUM_DEF" && num=$NUM_DEF
[ -z "$primitive" ] && info "Defaulting -m $PRIM_DEF" && primitive=$PRIM_DEF

re='^file:\/\/\/(.*)'
if [[ $input =~ $re ]]; then
	info "Stripping file uri: $input"
	input="/${BASH_REMATCH[1]}"
fi
dn=$(dirname "$input")
bn=$(basename "$input")

[ -z "$wdir" ] && wdir=$dn

#0=combo 1=triangle 2=rect 3=ellipse 4=circle 5=rotatedrect 6=beziers 7=rotatedellipse 8=polygon (default 1)
PRIMITIVES=(combo triangle rect ellipse circle rotatedrect beziers rotatdellipse polygon)
[ $primitive -ge ${#PRIMITIVES[*]} ] && die "Unknown primitive value $primitive"
primitive_name=${PRIMITIVES[$primitive]}

#echo primitive=$primitive
#echo primitive_name=$primitive_name

# create output from input if not given
if [ -z "$output" ]; then
	ext="${bn##*.}"
	fn="${bn%.*}"
	on="${fn}_${primitive_name}_${num}.${ext}"
	output="$wdir/$on"
fi

#~/gocode/bin/primitive -i /data/photos/steeve/nexus_5/DCIM/Camera/IMG_20170610_122050.jpg -o scenery_1000.jpg -m 1 -n 1000
cmd="~/gocode/bin/primitive $verbose -i \"$input\" -o \"$output\" -n $num -m $primitive $leftovers"
run ~/gocode/bin/primitive $verbose -i "$input" -o "$output" -n $num -m $primitive $leftovers

[ ! -z "$exif" ]   && run exiftool -TagsFromFile "$input" "$output"
[ ! -z "$viewer" ] && run $viewer "$output"
