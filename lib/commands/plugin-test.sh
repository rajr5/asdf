
plugin_test_command() {

    local plugin_name=$1
    local plugin_url=$2
    local plugin_command="${*:3}"

    local exit_code
    local TEST_DIR

    TEST_DIR=$(mktemp -dt asdf.XXXX)
    git clone "$ASDF_DIR/.git" "$TEST_DIR"

    fail_test() {
        echo "FAILED: $1"
        rm -rf "$TEST_DIR"
        exit 1
    }

    plugin_test() {
        export ASDF_DIR=$TEST_DIR

        # shellcheck disable=SC1090
        source "$ASDF_DIR/asdf.sh"

        if [ -z "$plugin_name" ] || [ -z "$plugin_url" ]; then
            fail_test "please provide a plugin name and url"
        fi

        if ! (asdf plugin-add "$plugin_name" "$plugin_url"); then
            fail_test "could not install $plugin_name from $plugin_url"
        fi

        if ! (asdf plugin-list | grep "^$plugin_name$" > /dev/null); then
            fail_test "$plugin_name was not properly installed"
        fi


        local versions
        # shellcheck disable=SC2046
        if ! read -r -a versions <<< $(asdf list-all "$plugin_name"); then
            fail_test "list-all exited with an error"
        fi

        if [ ${#versions} -eq 0 ]; then
            fail_test "list-all did not return any version"
        fi

        local latest_version
        latest_version=${versions[${#versions[@]} - 1]}

        if ! (asdf install "$plugin_name" "$latest_version"); then
            fail_test "install exited with an error"
        fi

        cd "$TEST_DIR" || fail_test "could not cd $TEST_DIR"

        if ! (asdf local "$plugin_name" "$latest_version"); then
            fail_test "install did not add the requested version"
        fi

        if ! (asdf reshim "$plugin_name"); then
            fail_test "could not reshim plugin"
        fi

        if [ -n "$plugin_command" ]; then
            $plugin_command
            exit_code=$?
            if [ $exit_code != 0 ]; then
                fail_test "$plugin_command failed with exit code $?"
            fi
        fi

        # Assert the scripts in bin are executable by asdf
        for filename in "$ASDF_DIR/plugins/$plugin_name/bin"/*
        do
            if [ ! -x "$filename" ]; then
                fail_test "Incorrect permissions on $filename. Must be executable by asdf"
            fi
        done

        # Assert that a license file exists in the plugin repo and is not empty
        license_file="$ASDF_DIR/plugins/$plugin_name/LICENSE"
        if [ -f "$license_file" ]; then
            if [ ! -s "$license_file" ]; then
                fail_test "LICENSE file in the plugin repository must not be empty"
            fi
        else
            fail_test "LICENSE file must be present in the plugin repository"
        fi
    }

    # run test in a subshell
    (plugin_test)
    exit_code=$?
    rm -rf "$TEST_DIR"
    exit $exit_code
}
