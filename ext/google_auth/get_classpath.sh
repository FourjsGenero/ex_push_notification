dir="$PWD/target/dependency"
for fn in `ls $dir`
do
    cp="$dir/$fn:$cp"
done
echo $cp
