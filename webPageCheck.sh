#!/bin/bash

# ===========================================================================
# Web Page Check
# ---------------------------------------------------------------------------
# Check the status of key Web websites.
#
# Calling instructions:
# ./webPageCheck.sh [switches]
#
# Command-line Switches:
#
# -v | --verbose        Outputs page configuration and troubleshooting info.
# -r | --show-response  Outputs curl response
# ===========================================================================
# Define the Page List
# ---------------------------------------------------------------------------
# Page list entries are defined using the
# following format:
#
# pageList+=("<Name of site>
# <Page URL>
# <Regex expression to indicate success>
# <Regex expression to indicate a maintenance page>
# <Form Action URL>
# ")
#
# NOTE: Searches will ignore case
# ---------------------------------------------------------------------------
echo Creating page list...
declare -a pageList

pageList+=("Google
https://www.google.com
<title>Google</title>
")

pageList+=("MSN
https://www.msn.com
<title>MSN
")

pageList+=("Github webPageCheck Repository
https://github.com/tomgehrke/webPageCheck
tomgehrke/webPageCheck
")

# ---------------------------------------------------------------------------
# Switch Variables
verbose=0
showResponse=''
# ---------------------------------------------------------------------------
# Regular Expressions
metaRefreshExp='\<meta http-equiv="refresh".*?content=".*?url=(.*?)"\>'
metaRefreshUrlExp='url=(.*)"'
inputTagsExp='\<input.*?\>'
inputInfoExp='.*name=\"(.*)\".*value=\"(.*)\"'
inputNameExp='name=\"\K(.*?)\"'
inputValueExp='value=\"\K(.*?)\"'
# ---------------------------------------------------------------------------
# Command Variabls
userAgent="Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0"
# ---------------------------------------------------------------------------
# Formatting Variables
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
NOCOLOR=$(tput sgr0)

totalWidth=$(tput cols)
lastColumnWidth=8
firstColumnWidth=$((totalWidth-lastColumnWidth))

pass="${GREEN} UP  ${NOCOLOR}"
warn="${YELLOW}MAINT${NOCOLOR}"
fail="${RED}DOWN!${NOCOLOR}"
leader=''

padChar(){
    for (( i=1; i<${totalWidth}+1; i++ ));
    do
        leader=$leader$1
    done
}
# ---------------------------------------------------------------------------
generateReport(){
    padChar '.'

    # Start Output
    clear
    echo Web Page Availability Status Checks
    echo ======================================
    echo $(date)
    echo ""

    # Start Scanning
    echo Beginning scan...
    echo --------------------------------------------

    # Make searches case insensitive
    shopt -s nocasematch

    for page in "${pageList[@]}"
    do
        # Initialize/Reset variables
        name=""
        url=""
        regexSuccess=""
        regexMaint=""
        formAction=""
        formData=""
        referer=""
        response=""
        status=""
        label=""

        # Parse page into array
        IFS=$'\n'
        read -a pageItem -d '' <<< "$page"

        # Pull out page item values
        name="${pageItem[0]}"
        url="${pageItem[1]}"
        regexSuccess="${pageItem[2]}"
        regexMaint="${pageItem[3]}"
        formAction="${pageItem[4]}"

        if [ $verbose = 1 ]; then
            echo "Name:        $name"
            echo "URL:         $url"
            echo "Success:     $regexSuccess"
            echo "Maint:       $regexMaint"
            echo "Form Action: $formAction"
            echo ----
        fi

        if [ "$url" != '' ]; then
            originalUrl="$url"
            while [ "$status" = '' ]
            do
                # curl switches rationale:
                # --silent: Suppresses the output to screen
                # --location: Follows redirects (302)
                # --user-agent: Pretend we're a real browser
                if [[ $formData = '' ]]; then
                    response=$(curl --silent --location --user-agent "$userAgent" "$url")
                else
                    # if [[ $verbose = 1 ]]; then
                    #    echo $formData
                    # fi

                    response=$(curl --silent --location "$formData" --referer "$referer" --user-agent "$userAgent" "$url")
                    formData=""
                fi

                if [[ $showResponse = 1 ]]; then
                    echo "$response"
                    echo ----
                fi

                if [[ "$regexSuccess" != "" && "$response" =~ "$regexSuccess" ]]; then
                    status=$pass
                else
                    if [[ "$regexMaint" != "" && "$response" =~ "$regexMaint" ]]; then
                        status=$warn
                    else
                        # Before failing, check to see if page is redirecting to
                        # another by using a meta refresh tag.
                        #
                        # This is a 2-step process where an "ungreedy" regex search
                        # is performed using grep which does not return groupings
                        # and then a bash regex match which only supports greedy
                        # searches but does return groupings.
                        metaRefreshTag=$(echo "$response" | grep -ioP --regexp="$metaRefreshExp")
                        if [[ "$metaRefreshTag" =~ $metaRefreshUrlExp ]]; then
                            url="${BASH_REMATCH[1]}"

                            if [[ $verbose = 1 ]]; then
                                echo "=> Meta refresh redirect to $url"
                            fi

                        else
                            # Before failing, check to see if a Form Action was
                            # provided for this target and whether that form
                            # exists on the current page.
                            if [[ "$formAction" != '' && "$response" =~ "$formAction" ]]; then
                                referer="$url"
                                url="$formAction"
                                inputTags="$(echo "$response" | grep -ioP --regexp="$inputTagsExp")"
                                while IFS= read -r tag; do
                                    inputName=$(echo "$tag" | grep -ioP --regexp="$inputNameExp")
                                    formData+="-F "
                                    formData+=${inputName%?}
                                    formData+="="
                                    inputValue=$(echo "$tag" | grep -ioP --regexp="$inputValueExp")
                                    formData+=${inputValue%?}
                                    formData+=" "
                                done <<< "$inputTags"

                                if [[ $verbose = 1 ]]; then
                                    echo "=> Form submission to $url"
                                fi
                            else
                                status=$fail
                            fi
                        fi
                    fi
                fi
            done
            if [ "$url" != "$originalUrl" ]; then
                label="$name ($originalUrl => $url)$leader"
            else
                label="$name ($originalUrl)$leader"
            fi
            printf "%.*s [%*s]\n" $firstColumnWidth $label $lastColumnWidth $status
            if [ $verbose = 1 ]; then
                echo --------------------------------------------
            fi
        fi
    done

    echo ""

    # Reset case sensitivity
    shopt -u nocasematch
}
# ---------------------------------------------------------------------------
loadArguments(){
    for arg in "$@"
    do
        case ${arg^^} in
            "-V" | "--VERBOSE")
                verbose=1
                ;;

            "-R" | "--SHOW-RESPONSE")
                showResponse=1
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
## MAIN
# ---------------------------------------------------------------------------
loadArguments "$@"
generateReport $1
