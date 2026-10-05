#!/bin/bash
# Сборка всех версий образа simple_python_app и фиксация размеров
cd "$(dirname "$0")/simple_python_app" || exit 1
OUT="$(dirname "$0")/image-sizes.txt"
: > "$OUT"
for v in v1 v2 v3 v4 v5 v6; do
  echo "===== building simple_python_app:$v ====="
  docker build -t "simple_python_app:$v" -f "Dockerfile.$v" . || echo "BUILD FAILED: $v"
  {
    echo "----- after $v -----"
    docker image ls simple_python_app
  } >> "$OUT"
done
echo "ALL DONE"
