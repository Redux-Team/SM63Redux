#!/usr/bin/env bash
# useful stuff:
# https://github.com/ClementPinard/python_filename_linter
# https://github.com/lint-staged/lint-staged
# https://git-scm.com/docs/git-update-index#Documentation/git-update-index.txt---cacheinfo
set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1


lintable() {
	grep -vE '(^|/)\.|^(addons|_local)/|\.(import|uid)$'
}


snake_case_pairs() {
	perl -ne '
		chomp; my $old = $_;
		my $new = join "/", map {
			my ($stem, $rest) = /^([^.]*)(.*)$/s;
			if (
				$stem !~ /^_?[a-z0-9]+(_[a-z0-9]+)*$/
				and not ($rest =~ /\.(md|txt)$/ and $stem =~ /^[A-Z]+$/)
			) {
				my $lead = $stem =~ /^_/ ? "_" : "";
				$stem =~ s/(?<=[a-z])(?=[A-Z])|(?<=[A-Z0-9])(?=[A-Z][a-z])|(?<=[0-9])(?=[a-z]{2})|(?<=[A-Za-z])(?=[0-9])/_/g;
				$stem = lc $stem;
				$stem =~ s/[^a-z0-9]+/_/g;
				$stem =~ s/^_+|_+$//g;
				$_ = $lead . $stem . $rest;
			}
			$_;
		} split m{/};
		print "$old\t$new\n" if $new ne $old;
	'
}


cache_name() {
	perl -MDigest::MD5=md5_hex -e '(my $file = $ARGV[0]) =~ s{.*/}{}; print "$file-", md5_hex($ARGV[0])' "$1"
}


move() {
	if [ ! -e "$1" ] || [ "$1" = "$2" ]; then
		return 0
	fi
	
	local mv=(mv)
	if git ls-files --error-unmatch -- "$1" > /dev/null 2>&1; then
		mv=(git mv)
	fi
	mkdir -p "$(dirname "$2")"
	"${mv[@]}" -- "$1" "$1.renaming" || return 1
	if [ -e "$2" ] || ! "${mv[@]}" -- "$1.renaming" "$2"; then
		"${mv[@]}" -- "$1.renaming" "$1"
		echo "pre-commit: can't rename $1 to $2, it already exists." >&2
		return 1
	fi
}


replace() {
	local mode
	local blob
	export OLD="$2" NEW="$3"
	mode="$(git ls-files -s -- "$1" | cut -d' ' -f1)"
	if [ -n "$mode" ]; then
		blob="$(git show ":$1" | perl -pe 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' | git hash-object -w --stdin)"
		git update-index --cacheinfo "$mode,$blob,$1"
	fi
	if [ -f "$1" ]; then
		perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$1"
	fi
}


replace_references() {
	{
		git -c core.quotePath=false grep -I -l -F -e "$1" --cached || true
		git -c core.quotePath=false grep -I -l -F -e "$1" || true
	} | sort -u | while IFS= read -r file; do
		replace "$file" "$1" "$2"
	done
}


renames="$(git -c core.quotePath=false diff --cached --name-only --diff-filter=AR | lintable | snake_case_pairs)"
if [ -z "$renames" ]; then
	exit 0
fi

dirs="$(printf '%s\n' "$renames" | perl -ne '
	chomp;
	my ($old, $new) = split /\t/;
	my @old = split m{/}, $old;
	my @new = split m{/}, $new;
	for my $i (0 .. $#old - 1) {
		print join("/", @old[0 .. $i]), "\t", join("/", @new[0 .. $i]), "\n" if $old[$i] ne $new[$i];
	}
' | sort -u)"
if [ -n "$dirs" ]; then
	renames="$(
		{
			printf '%s\n' "$renames"
			printf '%s\n' "$dirs" | cut -f1 | while IFS= read -r dir; do
				git -c core.quotePath=false ls-files -- "$dir/" | lintable | snake_case_pairs
			done
		} | sort -u
	)"
	while IFS=$'\t' read -r old new; do
		current="$(dirname "$new")/$(basename "$old")"
		move "${current#./}" "$new" || exit 1
	done <<< "$dirs"
fi

while IFS=$'\t' read -r old new; do
	current="$(dirname "$new")/$(basename "$old")"
	current="${current#./}"
	for mirror in "" .import .uid; do
		move "$current$mirror" "$new$mirror" || exit 1
	done
	
	if [ -f "$new.import" ]; then
		replace "$new.import" "$(cache_name "res://$old")" "$(cache_name "res://$new")"
		replace "$new.import" "res://$old" "res://$new"
	fi
	replace_references "res://$old" "res://$new"
	echo "pre-commit: renamed $old to $new" >&2
done <<< "$renames"

while IFS=$'\t' read -r old new; do
	if [ -n "$old" ]; then
		replace_references "res://$old/" "res://$new/"
	fi
done <<< "$dirs"
