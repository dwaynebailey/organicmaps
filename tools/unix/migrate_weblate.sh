#!/bin/bash

# Prepare Android files for Weblate
langs=$(egrep '=' data/strings/strings.txt | cut -d "=" -f1 | sed "s/[[:space:]]//g" | egrep -v "comment|tags|ref" | cut -d ":" -f 1 | sort -u)
android_strings_xml=$(find android/app/src/main/res/values* -name "strings.xml" -type f)

# Resolve any missing languages
for lang in $langs; do
	# https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes
	lang=${lang/he/iw}  # Hebrew
	lang=${lang/id/in}  # Indonesian
	lang=${lang/zh-Hans/zh}  # Chinese (Simplified)
	lang=${lang/zh-Hant/zh-TW}  # Chinese (Traditional)
	lang=${lang/-/-r}   # Region: e.g. en-rGB
	[[ $lang = "en" ]] && continue  # Skip source language
	ls android/app/src/main/res/values-$lang/strings.xml >/dev/null 2>&1 || (echo $lang - missing; mkdir -p android/app/src/main/res/values-$lang)
done
echo -n "Twine: "
echo "$langs" | wc -l
echo -n "Android: "
echo "$android_strings_xml" | wc -l

# Perform one last migration from source files
./tools/unix/generate_localizations.sh
