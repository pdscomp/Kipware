#!/usr/bin/env bash
# 
# Copyright (C) 2006 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
SELF=${0##*/}

[ -z "$STRIP" ] && {
  echo "$SELF: strip command not defined (STRIP variable not set)"
  exit 1
}

TARGETS=$*

[ -z "$TARGETS" ] && {
  echo "$SELF: no directories / files specified"
  echo "usage: $SELF [PATH...]"
  exit 1
}

find $TARGETS -not -path \*/lib/firmware/\* -a -type f -a -exec file {} \; | \
  sed -n -e 's/^\(.*\):.*ELF.*\(executable\|relocatable\|shared object\).*,.*/\1:\2/p' | \
(
  IFS=":"
  while read F S; do
    echo "$SELF: $F: $S"
	[ "${S}" = "relocatable" ] && {
		[ "${F##*.}" == "o" ] && continue
		eval "$STRIP_KMOD $F"
	} || {
		b=$(stat -c '%a' $F)
		case "${F##*/}" in
			ld-*.so|ld-linux*.so*)
				# Do not patchelf the runtime linker itself. Adding a new
				# PT_LOAD/RPATH segment to glibc's dynamic loader can make
				# dynamically linked programs segfault before main().
				;;
			*)
		[ -z "$PATCHELF" ] || [ -z "$TOPDIR" ] || {
			old_rpath="$($PATCHELF --print-rpath $F)"
			new_rpath=""
			for path in $old_rpath; do
				case "$path" in
					/lib|/usr/lib|/kip/lib|/kip/usr/lib|/lib/[^/]*|/usr/lib/[^/]*|/kip/lib/[^/]*|/kip/usr/lib/[^/]*|\$ORIGIN/*|\$ORIGIN) new_rpath="${new_rpath:+$new_rpath:}$path" ;;
					*) echo "$SELF: $F: removing rpath $path" ;;
				esac
			done
			# If no rpath existed, or if it changed, set the new one
			if [ -z "$old_rpath" ] || [ "$new_rpath" != "$old_rpath" ]; then
				if [ -z "$new_rpath" ]; then
					$PATCHELF --force-rpath --set-rpath "/kip/lib" $F
				else
					$PATCHELF --force-rpath --set-rpath "/kip/lib:$new_rpath" $F
				fi
			fi
		}
				;;
		esac
		eval "$STRIP $F"
		a=$(stat -c '%a' $F)
		[ "$a" = "$b" ] || chmod $b $F
	}
  done
  true
)
