#!/bin/bash

if [ "$1" == "-h" ]; then
    usage="$(basename "$0") [-h] [--tag] -- program to build and upload bokeh pkgs to binstar

    where:
        -h     show this help text
        --tag X.X.X-devel[rc] the tag string
    "
    echo "$usage"
    exit 0

elif [ "$1" == "--tag" ]; then
    tag=$2
    echo "$tag"
fi

# create a new branch from master
git checkout -b builds/devel task/devel_build #remove task/devel_build

# tag the branch
git tag -a $tag -m 'devel'

# get version number
version=`python scripts/get_bump_version.py`

# exit if there is no new tag
if [ "$version" == "No X.X.X-devel[rc] tag." ]; then
    echo You need to tag using the X.X.X-devel"[rc]" form before building.
    # delete the tag and checkout master
    git tag -d $tag
    git checkout task/devel_build #change to master
    exit 0
fi

# build for each python version
for py in 27 33 34;
do
    echo "Building py$py pkg"
    CONDA_PY=$py conda build conda.recipe --quiet
done

# get conda info about root_prefix and platform
function conda_info {
    conda info --json | python -c "import json, sys; print(json.load(sys.stdin)['$1'])"
}

CONDA_ENV=$(conda_info root_prefix)
PLATFORM=$(conda_info platform)
BUILD_PATH=$CONDA_ENV/conda-bld/$PLATFORM

# convert to platform-specific builds
conda convert -p all -f $BUILD_PATH/bokeh*$version*.tar.bz2;

#upload conda pkgs to binstar
array=(osx-64 linux-64 win-64 linux-32 win-32)
for i in "${array[@]}"
do
    echo Uploading: $i;
    #binstar upload -u bokeh $i/bokeh*$version*.tar.bz2 -c dev --force;
done

#create and upload pypi pkgs to binstar
#zip is currently not working

BOKEH_DEV_VERSION=$version python setup.py sdist --formats=gztar
#binstar upload -u bokeh dist/bokeh*$version* --package-type pypi -c dev --force;

echo "I'm done uploading"

#general clean up

# delete the tag
git tag -d $tag

# add all the generated files
git add .
git commit -m "Add all files."

# add all the generated files
git checkout -- .
git checkout task/devel_build #change to master
git branch -D builds/devel

#clean up
#for i in "${array[@]}"
#do
#    rm -rf $i
#done

#rm -rf dist/
#rm using_tags.txt

#####################
#Removing on binstar#
#####################


# remove entire release
# binstar remove user/package/release
# binstar --verbose remove bokeh/bokeh/0.4.5.dev.20140602

# remove file
# binstar remove user[/package[/release/os/[[file]]]]
# binstar remove bokeh/bokeh/0.4.5.dev.20140602/linux-64/bokeh-0.4.5.dev.20140602-np18py27_1.tar.bz2

# show files
# binstar show user[/package[/release/[file]]]
# binstar show bokeh/bokeh/0.4.5.dev.20140604
