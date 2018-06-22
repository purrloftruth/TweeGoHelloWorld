#!/usr/bin/env bash
#
# Copyright (c) 2018 Ruth Harris
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
#
# netlify-build.sh
#
# This script builds a Twine game with TweeGo on Netlify.
#
# Place netlify-build.sh at the base of your project's repository.
#
# This script assumes that you keep all your .tw sources in a discrete folder in
# your repository. (Of course, TweeGo allows you to have subfolders within it.)
# Set input_dir to the directory name in your repository where you keep your .tw
# sources. Set your Publish Directory on Netlify to "public".
#
# Changelog:
# 1.0.1:
#   * Rewrote testing structure so it properly works on Netlify
#   * Add verbose flag to hide `go get` printouts on normal operation
#   * Properly deletes old files before building again
#
# 1.0: initial release
#
# TODO: Support other story formats (we're currently locked into SugarCube 2.)
# This can be worked around by setting TWEEGO_FORMAT as an environment variable.
# TODO: Support exporting files from an asset directory to the output directory.
# (Most projects don't require this, but some might.)

input_dir="Source"
output_dir="public"

# Determine whether we're doing certain things verbosely
# (Thanks to http://wiki.bash-hackers.org/scripting/posparams)
while :
do
    case "$1" in
        -v | --verbose)
            verbose="verbose"
            shift
            ;;
        -*)
            # Leave us room for expansion if we need other options in future
            echo "Error: Unknown option: $1" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done


# Determine whether we need to build a testing build.
# This is done by checking what Netlify context we are in.
declare -A context_builds_debug_build=(
    [production]=false
    [deploy-preview]=true
    [branch-deploy]=true
)
# You can add your own contexts here if you need to.
# Obviously setting Production to true is not recommended...

# Include a default for if we get a context we don't understand
unknown_context_builds_debug_build=true

# Context also won't be set if we're running in Netlify's Docker build image
# locally.
context_to_set_for_docker_build_image="build-image-fake-context"
context_builds_debug_build[$context_to_set_for_docker_build_image]=true
if [ -z "$CONTEXT" ]
then
    export CONTEXT=$context_to_set_for_docker_build_image
    echo "⚠️ Empty context detected. Assuming we're running on a Docker build" \
         "image locally. Setting context to $CONTEXT."
    echo "If you're seeing this in your Netlify.com logs, something is wrong!"
    echo
fi

# We can guarantee context is set now. Let's see if we have knowledge of it

# If we don't know this context, (+_ - present, ! - not)
if [ ! ${context_builds_debug_build[$CONTEXT]+_} ]
then
    # We need to set a sane default.
    if [ $unknown_context_builds_debug_build = true ]
    then
        # We are building the debug version
        test_flag="-t"
        echo "Detected $CONTEXT context, but we don't know what that means."\
             "Building for testing."
    else
        # We are building the release version
        echo "Detected $CONTEXT context, but we don't know what that means."\
             "Building for release."
    fi
# If we do know the context, determine what we have it set for.
elif [ ${context_builds_debug_build[$CONTEXT]} = true ]
then
    # We are building the debug version
    test_flag="-t"
    echo "Detected $CONTEXT context. Building for testing."
else
    # We are building the release version
    echo "Detected $CONTEXT context. Building for release."
fi

# Make this whole fucker work
export PATH="${GOPATH}/bin:${PATH}"

# If we don't have tweego cached, install it
go list bitbucket.org/tmedwards/tweego > /dev/null 2>&1
if [ $? -ne 0 ]
then
    go_get_verbose_flag=""
    if [ "$verbose" ]
    then
        go_get_verbose_flag="-v"
    fi
    echo "Caching TweeGo..."
    go get $go_get_verbose_flag bitbucket.org/tmedwards/tweego
fi

# Build project, cleaning first
if [ -d "$output_dir" ]
then
    rm -rf $output_dir/
fi
mkdir -p $output_dir
echo \$ tweego $test_flag -l --log-files -o $output_dir/index.html $input_dir/
tweego $test_flag -l --log-files -o $output_dir/index.html $input_dir/
trv=$?
if [ $trv -eq 0 ]
then
    echo "🎉 Project appears to have compiled successfully (TweeGo returned 0.)"
    exit $trv
else
    echo "❌ Project didn't compile successfully (TweeGo returned $trv.)"
    exit $trv
fi
