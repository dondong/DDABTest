llvm_version=`llvm-config --version`
xcode_clang_version=`/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang --version | grep -e 'Apple clang version [0-9.]* (' `
xcode_clang_version=${xcode_clang_version#*Apple clang version }
xcode_clang_version=${xcode_clang_version% (*}

if [ llvm_version != xcode_clang_version ];
then
    # get released llvm for xcode clang version
    type jq >/dev/null 2>&1 || brew install jq
    echo "download llvm release list"
    release_array=`curl https://api.github.com/repos/llvm/llvm-project/releases`
    size=`echo $release_array | jq '. | length'`
    for index in `seq 0 $size`
    do
        item=`echo $release_array | jq .[$index]`
        name=`echo $item | jq .name`
        if [[ "$name" == "\"LLVM ${xcode_clang_version}\"" ]]; then
            echo "download llvm release version ${xcode_clang_version}"
            url=`echo $item | jq .zipball_url`
            url=${url#*\"}
            url=${url%\"}
            curl -L ${url} -o llvm.zip

            echo "begin unzip llvm"
            llvm_dir="~/Documents/llvm-project"
            unzip -q llvm.zip -d $llvm_dir
            rm llvm.zip
            echo "end unzip llvm"

            llvm_dir_name=`ls $llvm_dir`
            mv $llvm_dir ${llvm_dir}_tmp
            mv ${llvm_dir}_tmp/${llvm_dir_name} $llvm_dir
            rm -r ${llvm_dir}_tmp
            
            
            mkdir ~/Documents/llvm-build
            cd ~/Documents/llvm-build
            cmake -S ${llvm_dir}/llvm
            cmake --build .
            cmake --build . --target install
            
            break
        fi
    done
fi
