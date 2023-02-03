#!/bin/bash
#
# Generates a Git metrics dashboard in terminal.
#
# author: https://github.com/darul75

# https://stackoverflow.com/questions/1828874/generating-statistics-from-git-repository
# https://google.github.io/styleguide/shellguide.html
# https://unix.stackexchange.com/questions/225179/display-spinner-while-waiting-for-some-process-to-finish
# https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html

#######################################
# Constants
#######################################

AUTHOR_NOT_SET="AUTHOR_NOT_SET"
BEFORE_NOT_SET="BEFORE_NOT_SET"
AFTER_NOT_SET="AFTER_NOT_SET"

#######################################
# Helper functions
#######################################
function join_by { local IFS="$1"; shift; echo "$*"; }

function has_dependencies() {
    local cmd=$1
    local docs=$2
    if ! [ -x "$(command -v ${cmd})" ]; then
        printf "\nError: $cmd is not installed. \n\nSee $docs\n\n" >&2
        return 1
    fi
    return 0
}

function shutdown() {
    tput cnorm # reset cursor
}
trap shutdown EXIT

function cursorBack() {
    echo -en "\033[$1D"
}

function spinner() {
    # make sure we use non-unicode character type locale 
    # (that way it works for any locale as long as the font supports the characters)
    local LC_CTYPE=C

    local pid=$1 # Process Id of the previous running command

    case $(($RANDOM % 12)) in
    0)
        local spin='⠁⠂⠄⡀⢀⠠⠐⠈'
        local charwidth=3
        ;;
    1)
        local spin='-\|/'
        local charwidth=1
        ;;
    2)
        local spin="▁▂▃▄▅▆▇█▇▆▅▄▃▂▁"
        local charwidth=3
        ;;
    3)
        local spin="▉▊▋▌▍▎▏▎▍▌▋▊▉"
        local charwidth=3
        ;;
    4)
        local spin='←↖↑↗→↘↓↙'
        local charwidth=3
        ;;
    5)
        local spin='▖▘▝▗'
        local charwidth=3
        ;;
    6)
        local spin='┤┘┴└├┌┬┐'
        local charwidth=3
        ;;
    7)
        local spin='◢◣◤◥'
        local charwidth=3
        ;;
    8)
        local spin='◰◳◲◱'
        local charwidth=3
        ;;
    9)
        local spin='◴◷◶◵'
        local charwidth=3
        ;;
    10)
        local spin='◐◓◑◒'
        local charwidth=3
        ;;
    11)
        local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
        local charwidth=3
        ;;
    esac

    local i=0
    tput civis # cursor invisible
    # printf "%s" "Loading "
    while kill -0 $pid 2>/dev/null; do
        local i=$(((i + $charwidth) % ${#spin}))
        local loading="Loading"    
        printf "%s" "${spin:$i:$charwidth}"
        cursorBack 1
        sleep .1
    done
    tput cnorm
    wait $pid # capture exit code
    return $?
}

#######################################
# Git metrics extraction functions
#######################################

function get_repo_name() {
    echo "$(basename `git rev-parse --show-toplevel`)"
}

function get_repo_file_count() {
    echo $(git ls-files | wc -l)
}

function get_author_param() {
    local author="$1"
    if [ "$author" = "$AUTHOR_NOT_SET" ]; then
        author=""
    fi 
    echo "$author"
}

function get_after_git_param() {
    local after="$1"
    
    [ "$after" = "$AFTER_NOT_SET" ] && after=""
    ! [ -z $after ] && after="--after=$after"

    echo "${after}"
}

function get_before_git_param() {
    local before="$1"
    
    [ "$before" = "$BEFORE_NOT_SET" ] && before=""
    ! [ -z $before ] && before="--before=$before"

    echo "${before}"
}

function get_author_first_commit_date() {
    local author=$(get_author_param "$1")
    local after=$(get_after_git_param $2)
    local before=$(get_before_git_param $3)

    # TODO: -all option?

    first_commit_date=$(git log --reverse --author="$author" $after $before --date=short | grep "Date" | head -n1 | sed "s/Date:[[:space:]]\{3\}//g")
    echo "${first_commit_date}"
}

function get_author_last_commit_date() {
    local author=$(get_author_param "$1")
    local after=$(get_after_git_param $2)
    local before=$(get_before_git_param $3)

    local out=$(git log --format=%cs --author="$author" $after $before -n 1)
    echo "${out}"
}

function get_authors() {
    local after=$(get_after_git_param $1)
    local before=$(get_before_git_param $2)
    local authors=$(git log --pretty="%an" $after $before | sort | uniq -c | sort | awk '{$1=$1};1' | tr '\n' ',' | sed "s/\"//g" | sed "s/^/\[\"/" | sed "s/,/\",\"/g" | sed 's/.\{2\}$//' | sed "s/$/\]/")
    echo "${authors}"
}

function get_author_count() {
    local count=$(git log --format='%ae' | sort -u | wc -l | awk '{$1=$1};1')
    echo "${count}"
}

function get_author_commit_count() {
    local author=$(get_author_param "$1")
    local after=$(get_after_git_param $2)
    local before=$(get_before_git_param $3)

    local count=$(git log --date=short --pretty=format:%ad --author="$author" $after $before | sort | uniq -c | awk '{$1=$1};1' | awk 'NR > 1 { printf("\n") } {printf "%s",$0}' | cut -d' ' -f1 | awk '{ printf "%s,", $0 }' | sed "s/^/\[/" | sed "s/$/\]/")
    [ -z "$count" ] && echo "[]"
    echo "${count}"
}

function get_author_commit_dates() {
    local author=$(get_author_param "$1")
    local after=$(get_after_git_param $2)
    local before=$(get_before_git_param $3)

    local dates=$(git log --date=short --pretty=format:%ad --author="$author" $after $before | sort | uniq -c | awk '{$1=$1};1' | awk 'NR > 1 { printf("\n") } {printf "%s",$0}' | cut -d' ' -f2 | awk '{ printf "'\''%s'\','", $0 }' | sed "s/^/\[/" | sed "s/$/\]/")
    [ -z "$dates" ] && echo "[]"
    echo "${dates}"
}

function get_author_commit_count_since() {
    local author=$(get_author_param "$1")
    local after=$(get_after_git_param $2)
    local before=$(get_before_git_param $3)

    local count=$(git rev-list HEAD --count --author="$author" $after $before)
    echo "${count}"
}

function get_author_commit_messages() {
    local author=$(get_author_param "$1")
    local count=$2
    local after=$(get_after_git_param $3)
    local before=$(get_before_git_param $4)

    local messages=$(git log --author="$author" --pretty=oneline $after $before --no-merges -n${count} | cut -d' ' -f 2- | tail -r -n ${count} | sed "s/\"//g" | sed "s/\"//g" | sed "s/,//g" | tr '\n' ','  | sed "s/^/\[\"/" | sed "s/,/\",\"/g" | sed 's/.\{2\}$//'  | sed "s/$/\]/")
    echo "${messages}"
}

function get_top_modified_files() {
    local author=$(get_author_param "$1")
    local count=$2
    local after=$(get_after_git_param $3)
    local before=$(get_before_git_param $4)

    local files=$(git log --name-only --author="$author" --pretty=format: $after $before | awk NF | sort | uniq -c | sort -rg | head -n ${count} |  tail -r -n ${count} | tr '\n' ',' | sed "s/^/\[\"/" | sed "s/,/\",\"/g" | sed 's/.\{2\}$//'  | sed "s/$/\]/")
    echo "${files}"
}

function get_author_deletions() {
    local author=$(get_author_param "$1")
    local after=$(get_after_git_param $2)
    local before=$(get_before_git_param $3)

    local logs=$(git log --author="$author" --shortstat --pretty=tformat: $after $before | grep deletion | grep insertion | sed 's/\(\d*\) deletions\{0,1\}(-)/\1/' | awk '{ print $NF }'  | tr '\n' ',')
    echo "[${logs}]"
}

function get_author_insertions() {
    local author=$(get_author_param "$1")
    local after=$(get_after_git_param $2)
    local before=$(get_before_git_param $3)

    local logs=$(git log --author="$author" --shortstat --pretty=tformat: | grep deletion | grep insertion | sed 's/\(\d*\) insertion\{0,1\}(-)/\1/' | awk '{ print $4 }'  | tr '\n' ',')
    echo "[${logs}]"
}

function main() {
    # git installed
    if ! has_dependencies git "https://git-scm.com/"; then return 0; fi

    # python installed
    local pythonInstall=0
    if command -v python > /dev/null
    then
        (( pythonInstall |= 1 ))
        python -m pip install -r requirements.txt > /dev/null
    fi
    if command -v python3 > /dev/null
    then
        (( pythonInstall |= 1 ))
        python3 -m pip install -r requirements.txt > /dev/null
    fi

    if [ $pythonInstall -eq 0 ]; then
        echo "Error: please install Python or Python3"
        exit 1
    fi

    # args
    local theme='dark'
    if [ "$1" = "${AUTHOR_NOT_SET}" ]; then
        author=$AUTHOR_NOT_SET
    else
        author="$1"
    fi

    if [ -z "$2" ]; then
        :
    else
        theme="$2"
    fi

    local after="$3"
    local before="$4"

    local first_commit_date=$(get_author_first_commit_date "$author" "$after" "$before")
    if [ -z "${first_commit_date}" ]
    then
        echo "Author '${author}' not found in git, try again!"
    else
        local repo_name=$(get_repo_name)
        local repo_file_count=$(get_repo_file_count)
        local author=$(echo $author)
        local authorLastCommitDate=$(get_author_last_commit_date "$author" "$after" "$before")
        local author_count=$(get_author_count)
        ! [ "$after" = "$AFTER_NOT_SET" ] && first_commit_date="$after"
        local authors=$(get_authors "$first_commit_date" "$before")
        local dates=$(get_author_commit_dates "$author" "$after" "$before")
        local commits=$(get_author_commit_count "$author" "$after" "$before")
        local last_week_date=$(date -v-7d "+%Y-%m-%d")
        local last_month_date=$(date -v-1m "+%Y-%m-%d")
        local last_year_date=$(date -v-1y "+%Y-%m-%d")
        local total_commits=$(get_author_commit_count_since "$author" "$first_commit_date" "$before")
        local weekly_commits=$(get_author_commit_count_since "$author" "$last_week_date" "$before")
        local monthly_commits=$(get_author_commit_count_since "$author" "$last_month_date" "$before")
        local yearly_commits=$(get_author_commit_count_since "$author" "$last_year_date" "$before")
        local deletions=$(get_author_deletions "$author" $after $before)
        local insertions=$(get_author_insertions "$author" $after $before)
        local commit_messages=$(get_author_commit_messages "$author" 100 "$after" "$before")
        local log_top_file=$(get_top_modified_files "$author" 100 "$after" "$before")

read -r -d '' pythonScript <<- EOM
import plotext as plt
import datetime as DT
import math
from plotext._utility import themes as _theme

# theme
current_theme='${theme}'
plt.theme(current_theme)

# variables
text_height_ratio = 0.3
today = DT.date.today()
week_ago = today - DT.timedelta(days=7)
repo_name = '${repo_name}'
repo_file_count = '${repo_file_count}'
author = '${author}'
authorNotSet = '${AUTHOR_NOT_SET}'
author_count = '${author_count}'
total_commits = '${total_commits}'
authorLastCommitDate = '${authorLastCommitDate}'
firstCommitDate = '${first_commit_date}'
commits = list(${commits})
dates = list(${dates})
commitLogs = list(${commit_messages})
authors = list(${authors})
topfiles = list(${log_top_file})
insertions = list(${insertions})
deletions = list(${deletions})
sumInsertions = sum(insertions)
sumDeletions = sum(deletions)
insertionsX = list(range(0,len(insertions),1))
deletionsX = list(range(0,len(deletions),1))

##########################################################################################
#                                       #           #           #           #            #
#                                       #   Weekly  #  Monthly  #  Yearly   # Ins vs Del #
#  Graph commit history                 #           #           #           #            #
#                                       #           #           #           #            #
#                                       ##################################################
#                                       #                       #                        #
#                                       #                       #                        #
#                                       #       General info    #      Top Authors       #
#                                       #                       #                        #
#                                       #                       #                        #
#                                       ##################################################
#                                       #                                                #
#                                       #                                                #
#                                       #                  Commit logs                   #
#                                       #                                                #
#                                       #                                                #
#                                       #                                                #
#                                       #                                                #
#                                       #                                                #
#                                       #                                                #
#                                       #                                                #
#                                       #                                                #
##########################################################################################
#                                       #                                                #
#                                       #                                                #
#        Graph Ins vs Del               #                  Top files edited              #
#                                       #                                                #
#                                       #                                                #
###########################################################################################

# layout
plt.subplots(2, 2)
plt.subplot(1, 1).subplots(1, 1)
plt.subplot(1, 2).subplots(3, 1)
plt.subplot(1, 3).subplots(1, 1)
plt.subplot(1, 2).subplot(1, 1).subplots(1,4)
plt.subplot(1, 2).subplot(2, 1).subplots(1,2)

## GRAPH COMMIT HISTORY
plt.subplot(1, 1).subplot(1, 1)
if len(commits) == 0 :
    maxY = 1
else:
    maxY = max(commits) + 1

yRange = list(range(0, maxY, 1))

def stringigy_number(n):
    return str(int(n))

yRangeLabels = map(stringigy_number, yRange)

# str(int(f))
plt.yticks(yRange, yRangeLabels)
plt.yfrequency(1)
plt.date_form('Y-m-d')
start = plt.string_to_datetime(firstCommitDate)
end = plt.today_datetime()
plt.ylim(1, maxY)

if len(commits) == 0 :
    plt.bar([], [], marker = 'sd')
else:
    plt.bar(dates, commits, marker = 'sd')

plt.title('Commit history')
plt.xlabel('')
plt.ylabel('')

## WEEKLY
plt.subplot(1, 2).subplot(1, 1).plot_size(None, 6)
plt.subplot(1, 2).subplot(1, 1).subplot(1, 1)
plt.indicator("${weekly_commits}", 'Weekly', color = _theme[current_theme][2])

## MONTHLY
plt.subplot(1, 2).subplot(1, 1).subplot(1, 2)
plt.indicator("${monthly_commits}", 'Monthly', color = _theme[current_theme][2])

## YEARLY
plt.subplot(1, 2).subplot(1, 1).subplot(1, 3)
plt.indicator("${yearly_commits}", 'Yearly', color = _theme[current_theme][2])

## INVSERTIONS VS DELETION
plt.subplot(1, 2).subplot(1, 1).subplot(1, 4)
plt.indicator(f'{sumInsertions}/{sumDeletions}', 'Insertions vs deletions', color = _theme[current_theme][2])

## GENERAL INFO
plt.subplot(1, 2).subplot(2, 1).subplot(1, 1).title('General')
plt.subplot(1, 2).subplot(2, 1).plot_size(None, 10)
plt.subplot(1, 2).subplot(2, 1).subplot(1, 1)
plt.scatter([0, 1], marker = ' ')
plt.yfrequency(0)
plt.xfrequency(0)
if author == authorNotSet:
    genaral_info=f'Repository: {repo_name}\nFiles #: {repo_file_count}\nTotal authors: {author_count}\nTotal commits: {total_commits}\nFirst commit: {firstCommitDate}\nLast commit: {authorLastCommitDate}'
else:
    genaral_info=f'Repository: {repo_name}\nFiles #: {repo_file_count}\nAuthor: {author}\nTotal authors: {author_count}\nTotal commits: {total_commits}\nFirst commit: {firstCommitDate}\nLast commit: {authorLastCommitDate}'
plt.text(genaral_info, 1, 1, alignment = 'left')

## TOP AUTHORS
plt.subplot(1, 2).subplot(2, 1).subplot(1, 2).title('Authors')
plt.scatter([0, 1], marker = ' ')
plt.yfrequency(0)
plt.xfrequency(0)
authors = '\n'.join(reversed(authors))
plt.text(authors, 1, 1, alignment = 'left')

## COMMITS LOGS
plt.subplot(1, 2).subplot(3, 1).title('Logs')
plt.scatter([0, 1], marker = ' ')
plt.yfrequency(0)
plt.xfrequency(0)

logs = '\n'.join(reversed(commitLogs))
plt.text(logs, 1, 1, alignment = 'left')

## TOP FILES
plt.subplot(2, 2).plot_size(None, 20)
plt.subplot(2, 2).title('Top files')
plt.scatter([0, 1], marker = ' ')
plt.yfrequency(0)
plt.xfrequency(0)
files = '\n'.join(reversed(topfiles))
plt.text(files, 1, 1, alignment = 'left')

## INS vs DEL
plt.subplot(2, 1)

if len(insertions) > 0 and len(deletions) > 0 :
    plt.stacked_bar(deletionsX, [insertions, deletions], label = ['Insertions', 'Deletions'], fill = None, minimum = 1)

plt.title('Insertions vs Deletions')
plt.show()
EOM

        plotextDoc="https://pypi.org/project/plotext/"

        if ! [ -x "$(command -v python3)" ]; then
            python -c "${pythonScript}"
        else
            python3 -c "${pythonScript}"
        fi
        res=$?
        if [ $res -eq 0 ]; then
            :
        else
            printf "\nSomething went wrong, sorry.\n\n" >&2
            exit 1
        fi
    fi
}

#######################################
# CLI
#######################################

function usage() {
    __usage="
    Usage: $0 [ -n NAME ] [ -t THEME ] [ -A AFTER_DATE ] [ -B BEFORE_DATE ]

    Options:
    -a <author>       Git author (optional)
    -t <theme>        Theme (optional, default 'dark'): 'default'|'clear'|'pro'|'matrix'|'windows'|'dark'|'retro'|'elegant'|'mature'|'dreamland'|'grandpa'|'salad'|'girly'|'serious'|'sahara'|'scream'
    -A <after>        More recent than a specific date (YYYY-MM-DD)
    -B <before>       Older than a specific date (YYYY-MM-DD)
    -h                Help
    "
    echo "$__usage" 1>&2
}

function exit_abnormal() {
    usage
    exit 1
}

AUTHOR="${AUTHOR_NOT_SET}"
THEME="dark"
AFTER="${AFTER_NOT_SET}"
BEFORE="${BEFORE_NOT_SET}"

while getopts ":a:t:hA:B:" options; do
    case "${options}" in
        a)
        AUTHOR=${OPTARG}
        ;;
        t)
        THEME=${OPTARG}
        ;;
        A)
        AFTER=${OPTARG}
        ;;
        B)
        BEFORE=${OPTARG}
        ;;
        h)
        exit_abnormal
        ;;
        :)
        exit_abnormal
        ;;
        *)
        exit_abnormal
        ;;
    esac
done

main "${AUTHOR}" "${THEME}" "${AFTER}" "${BEFORE}" & spinner $! && exit 0