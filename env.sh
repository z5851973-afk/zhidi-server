# 智递项目 - Java & Maven 环境配置
# 使用前执行: source ~/Documents/zhidi/env.sh

export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

MVN="/Users/liupei/.m2/wrapper/dists/apache-maven-3.9.16/56ba1f9f/bin/mvn"
PROJECT="/Users/liupei/Documents/zhidi/zhidi_server"

alias mvn="$MVN"
alias zhidi="cd $PROJECT"

echo "[zhidi] JAVA_HOME=$JAVA_HOME"
echo "[zhidi] mvn → $(dirname $MVN)"
echo "[zhidi] project → $PROJECT"
