#!/bin/sh

# Don't let locale affect this script.
LC_ALL=C
LANG=C
export LC_ALL LANG

command_list () {
	sed '1,/^### command list/d;/^#/d' "$1"
}

category_list () {
	command_list "$1" | awk '{print $2;}' | sort | uniq
}

echo "/* Automatically generated by generate-cmdlist.sh */
struct cmdname_help {
	char name[32];
	char help[80];
	unsigned int category;
	unsigned int group;
};

static const char *common_cmd_groups[] = {"

grps=grps$$.tmp
trap "rm -f '$grps'" 0 1 2 3 15

sed -n '
	1,/^### common groups/b
	/^### command list/q
	/^#/b
	/^[ 	]*$/b
	h;s/^[^ 	][^ 	]*[ 	][ 	]*\(.*\)/	N_("\1"),/p
	g;s/^\([^ 	][^ 	]*\)[ 	].*/\1/w '$grps'
	' "$1"
printf '};\n\n'

echo "#define GROUP_NONE 0xff /* no common group */"
n=0
while read grp
do
	echo "#define GROUP_${grp:-NONE} $n"
	n=$(($n+1))
done <"$grps"
echo

echo '/*'
printf 'static const char *cmd_categories[] = {\n'
category_list "$1" |
while read category; do
	printf '\t\"'$category'\",\n'
done
printf '\tNULL\n};\n\n'
echo '*/'

n=0
category_list "$1" |
while read category; do
	echo "#define CAT_$category $n"
	n=$(($n+1))
done
echo

printf 'static struct cmdname_help command_list[] = {\n'
command_list "$1" |
sort |
while read cmd category tags
do
	if [ "$category" = guide ]; then
		name=${cmd/git}
	else
		name=${cmd/git-}
	fi
	sed -n '
		/^NAME/,/'"$cmd"'/H
		${
			x
			s/.*'"$cmd"' - \(.*\)/	{"'"$name"'", N_("\1"), CAT_'$category', GROUP_'${tags:-NONE}' },/
			p
		}' "Documentation/$cmd.txt"
done
echo "};"
