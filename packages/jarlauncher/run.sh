set -eu

APPLICATION_DIRECTORY=/mnt/us/extensions/JarLauncher
JAVA=${APPLICATION_DIRECTORY}/Java/bin/java
CONFIG=${APPLICATION_DIRECTORY}/bin/config.sh

if [ ! -x "${JAVA}" ]; then
  printf '%s\n' 'The packaged Java runtime is unavailable' >&2
  exit 1
fi
if [ ! -f "${CONFIG}" ]; then
  printf '%s\n' 'JarLauncher configuration is unavailable' >&2
  exit 1
fi

JARLAUNCHER_DIR=${APPLICATION_DIRECTORY}
JAVA_ARGS=-Xss512k
JAR_PATH=${APPLICATION_DIRECTORY}/jar.jar
JAR_ARGS=
. "${CONFIG}"

if [ ! -f "${JAR_PATH}" ]; then
  printf '%s\n' "Java archive is unavailable: ${JAR_PATH}" >&2
  exit 1
fi

cd "${APPLICATION_DIRECTORY}/run"
exec "${JAVA}" ${JAVA_ARGS} -jar "${JAR_PATH}" ${JAR_ARGS}
