# 40_copy_as_is.sh
#
# copy files and directories that should be copied over as-is to the rescue
# systems. Checks also for library dependancies of executables and adds
# them to the LIBS list, if they are not included in the copied files.

LogPrint "Copy files and directories"
Log "Will copy ${COPY_AS_IS[@]} and exclude ${COPY_AS_IS_EXCLUDE[@]}"
for f in "${COPY_AS_IS_EXCLUDE[@]}" ; do echo "$f" ; done >$TMP_DIR/copy-as-is-exclude
tar -X $TMP_DIR/copy-as-is-exclude \
	-P -C / -v -c "${COPY_AS_IS[@]}" 2>$TMP_DIR/copy-as-is-filelist | \
	tar -C $ROOTFS_DIR/ -xv >&8
StopIfError "Could not copy files and directories"
Log "Finished copying COPY_AS_IS"

COPY_AS_IS_EXELIST=()
while read -r ; do
	if [[ ! -d "$REPLY" && -x "$REPLY" ]]; then
		COPY_AS_IS_EXELIST=( "${COPY_AS_IS_EXELIST[@]}" "$REPLY" )
	fi
	echo "$REPLY" >&8
done <$TMP_DIR/copy-as-is-filelist

Log "Checking COPY_AS_IS_EXELIST"
# add required libraries to LIBS, skip libraries that are part of the copied files.
while read -r ; do
	lib="$REPLY"
#	if ! grep -q "$lib" <<<"${COPY_AS_IS_EXELIST[@]}"; then
	if ! IsInArray "$lib" "${COPY_AS_IS_EXELIST[@]}"; then
		# if $lib is NOT part of the copy-as-is fileset, then add it to the global libs
		LIBS=( ${LIBS[@]} $lib )
		Log "Adding required $lib to LIBS"
		echo "adding $lib to LIBS"
	else
		echo "$lib is part of COPY_AS_IS_EXELIST"
	fi
done >&8 < <( SharedObjectFiles "${COPY_AS_IS_EXELIST[@]}" | sed -e 's#^#/#' )
